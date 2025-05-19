import 'dart:async'; // Để sử dụng Timer
import 'dart:convert'; // Để sử dụng jsonEncode và jsonDecode
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart'; // Hoặc web_socket_channel/html.dart nếu cho web
import 'package:intl/intl.dart'; // Để định dạng thời gian

// Enum để quản lý vai trò của tin nhắn, giúp UI dễ dàng phân biệt
enum MessageRole {
  user_typed, // Tin nhắn do người dùng gõ
  user_stt,   // Tin nhắn là kết quả STT giọng nói của người dùng (server gửi về)
  chatbot     // Tin nhắn từ chatbot (server gửi về)
}

// Class dữ liệu cho mỗi tin nhắn trong danh sách
class ChatMessageData {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessageData({
    required this.text,
    required this.role,
    required this.timestamp,
  });
}

class ChatBotPage extends StatefulWidget {
  @override
  _ChatBotPageState createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  IOWebSocketChannel? _channel;
  final List<ChatMessageData> _messages = [];

  bool _isConnected = false;
  String _connectionStatus = "Đang kết nối...";
  bool _isServerListening = false; // Server đã xác nhận đang nghe

  // Trạng thái cho UI của nút mic và modal
  bool _isVoiceInputLoading = false; // Hiển thị loading trước modal (2s)
  Timer? _voiceLoadingTimer;
  bool _isShowingListeningModal = false; // Modal "Đang lắng nghe" có đang hiển thị không

  final String _webSocketUrl = 'ws://10.0.2.2:8765'; // Mặc định cho Android Emulator
  // final String _webSocketUrl = 'ws://localhost:8765'; // Nếu chạy Flutter Desktop trên cùng máy server
  // final String _webSocketUrl = 'ws://YOUR_RASPBERRY_PI_IP:8765'; // Khi server ở máy khác

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _voiceLoadingTimer?.cancel();
    _channel?.sink.close();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    _voiceLoadingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isVoiceInputLoading = false;
        _connectionStatus = "Đang kết nối đến $_webSocketUrl...";
        _isConnected = false;
        _messages.clear();
      });
    }
    _addSystemMessage("Đang thử kết nối đến server...");

    if (_isShowingListeningModal) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _isShowingListeningModal = false;
    }

    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(_webSocketUrl));
      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectionStatus = "Đã kết nối!";
        });
      }
      _addSystemMessage("Kết nối thành công!");

      _channel!.stream.listen(
            (data) {
          _handleWebSocketMessage(data);
        },
        onDone: () {
          _handleDisconnection("Server đã ngắt kết nối.");
        },
        onError: (error) {
          _handleDisconnection("Lỗi kết nối WebSocket: $error");
        },
        cancelOnError: true, // Quan trọng: tự động hủy subscription khi có lỗi
      );
    } catch (e) {
      _handleDisconnection("Không thể khởi tạo kết nối: $e");
    }
  }

  void _handleDisconnection(String message) {
    if (!mounted) return;
    _voiceLoadingTimer?.cancel();
    if (_isShowingListeningModal) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _isShowingListeningModal = false;
    }
    setState(() {
      _isConnected = false;
      _isServerListening = false;
      _isVoiceInputLoading = false;
      _connectionStatus = message;
    });
    _addSystemMessage("WebSocket connection issue: $message");
  }


  void _handleWebSocketMessage(dynamic data) {
    if (!mounted) return;
    _addSystemMessage('Raw data received from server: $data');
    try {
      final decodedData = jsonDecode(data as String);
      final event = decodedData['event'] as String?;

      if (event == null) {
        _addSystemMessage("Lỗi: Server gửi sự kiện không hợp lệ (event is null).");
        return;
      }

      switch (event) {
        case 'listening':
          if (mounted) {
            setState(() {
              _isServerListening = true;
            });
          }
          _addSystemMessage("Server đang lắng nghe giọng nói...");
          break;
        case 'chat_message':
          final roleString = decodedData['role'] as String?;
          final messageText = decodedData['message'] as String?;

          if (roleString != null && messageText != null) {
            MessageRole role;
            if (roleString == 'user_stt') {
              role = MessageRole.user_stt;
              if (_isShowingListeningModal) {
                if (Navigator.canPop(context)) Navigator.of(context, rootNavigator: true).pop();
                // _isShowingListeningModal sẽ được set false trong .then() của showDialog
              }
              if (mounted) {
                setState(() {
                  _isServerListening = false;
                });
              }
              _addSystemMessage("Server đã gửi kết quả STT.");
            } else if (roleString == 'chatbot') {
              role = MessageRole.chatbot;
            } else {
              _addSystemMessage("Lỗi: Vai trò không xác định từ server ($roleString).");
              return;
            }
            _addChatMessage(messageText, role);
          } else {
            _addSystemMessage("Lỗi: Dữ liệu tin nhắn không hợp lệ từ server.");
          }
          break;
        case 'error':
          final errorMessage = decodedData['message'] as String?;
          _addSystemMessage("Lỗi từ Server: ${errorMessage ?? 'Không rõ lỗi'}");
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi từ Server: ${errorMessage ?? 'Không rõ lỗi'}')),
            );
          }
          if (_isShowingListeningModal) {
            if (Navigator.canPop(context)) Navigator.of(context, rootNavigator: true).pop();
          }
          if (mounted) {
            setState(() {
              _isServerListening = false;
              _isVoiceInputLoading = false;
            });
          }
          break;
        case 'stop_listening_ack':
          _addSystemMessage("Received stop_listening_ack from server.");
          // UI đã được cập nhật ở client
          break;
        default:
          _addSystemMessage("Lỗi: Sự kiện không xác định từ server ($event).");
      }
    } catch (e) {
      _addSystemMessage("Lỗi xử lý dữ liệu từ server: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý dữ liệu từ server.')),
        );
      }
    }
    if (mounted) _scrollToBottom();
  }

  void _addChatMessage(String text, MessageRole role) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessageData(
        text: text,
        role: role,
        timestamp: DateTime.now(),
      ));
    });
    // _scrollToBottom() sẽ được gọi sau khi xử lý message từ server
  }

  void _addSystemMessage(String text) {
    // In ra console để debug, không hiển thị trực tiếp trên UI tin nhắn
    print("System Message: $text");
  }

  void _performStopListeningSequence() {
    if (!mounted) return;
    _addSystemMessage("Thực hiện chuỗi dừng ghi âm.");
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({'event': 'stop_listening'}));
      _addSystemMessage("Đã gửi yêu cầu stop_listening đến server.");
    } else if (!_isVoiceInputLoading) {
      _showConnectionErrorSnackbar("Chưa kết nối để gửi lệnh dừng ghi âm.");
    }
    setState(() {
      _isServerListening = false; // Cập nhật UI icon mic
    });
  }


  void _showListeningModal() {
    if (!mounted || _isShowingListeningModal) return;

    _isShowingListeningModal = true;
    _addSystemMessage("Hiển thị modal 'Đang lắng nghe'.");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text("Ghi Âm", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                "Đang lắng nghe giọng nói của bạn...",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              child: Text('HỦY', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performStopListeningSequence();
                _addSystemMessage("Người dùng nhấn Hủy từ modal.");
              },
            ),
          ],
        );
      },
    ).then((_) {
      _addSystemMessage("Modal 'Đang lắng nghe' đã đóng.");
      if (!mounted) return;
      _isShowingListeningModal = false;
      // Đảm bảo setState được gọi để cập nhật UI nút mic nếu cần
      // ví dụ: modal đóng do lỗi mạng, không phải do người dùng hay server
      if (mounted) setState(() {});
    });
  }

  void _startVoiceInput() {
    if (_channel == null || !_isConnected) {
      _showConnectionErrorSnackbar("Chưa kết nối đến server để bắt đầu ghi âm.");
      return;
    }
    if (_isVoiceInputLoading || _isServerListening || _isShowingListeningModal) {
      _addSystemMessage("Bỏ qua _startVoiceInput: đang loading hoặc server/modal đang hoạt động.");
      return;
    }

    if (mounted) {
      setState(() {
        _isVoiceInputLoading = true;
      });
    }
    _addSystemMessage("Bắt đầu delay 2s cho ghi âm...");

    _voiceLoadingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        _addSystemMessage("Timer callback: Widget unmounted. Hủy.");
        return;
      }

      // Luôn set _isVoiceInputLoading = false sau timer, bất kể kết quả
      if (mounted) {
        setState(() {
          _isVoiceInputLoading = false;
        });
      }

      if (!_isConnected || _channel == null) {
        _addSystemMessage("Mất kết nối trong 2s chờ. Không gửi lệnh start_listening.");
        _showConnectionErrorSnackbar("Không thể bắt đầu ghi âm, kết nối bị mất.");
        if(mounted) setState(() { _isServerListening = false; }); // Reset server listening state
        return;
      }

      _addSystemMessage("Delay 2s hoàn tất, kết nối OK. Hiển thị modal và gửi lệnh.");
      _showListeningModal();
      _channel!.sink.add(jsonEncode({'event': 'start_listening'}));
    });
  }

  void _stopVoiceInput() {
    _addSystemMessage("Yêu cầu dừng ghi âm (từ nút mic hoặc logic khác).");
    _voiceLoadingTimer?.cancel();
    if (!mounted) return;

    if (mounted) {
      setState(() {
        _isVoiceInputLoading = false;
      });
    }

    if (_isShowingListeningModal) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    _performStopListeningSequence();
  }


  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      if (_channel != null && _isConnected) {
        _addChatMessage(text, MessageRole.user_typed);
        _channel!.sink.add(jsonEncode({'event': 'text_message', 'text': text}));
        _textController.clear();
        _scrollToBottom(); // Cuộn xuống sau khi gửi tin nhắn text
      } else {
        _showConnectionErrorSnackbar("Chưa kết nối đến server để gửi tin nhắn.");
      }
    }
  }

  void _showConnectionErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _scrollToBottom() {
    // Đảm bảo chỉ cuộn khi có client và sau khi frame đã build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget micButtonChild;
    VoidCallback? micButtonPressed;
    String micTooltip;

    if (_isVoiceInputLoading) {
      micButtonChild = SizedBox(
        width: 24, // Kích thước của CircularProgressIndicator
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
        ),
      );
      micButtonPressed = null;
      micTooltip = 'Đang chuẩn bị ghi âm...';
    } else if (_isServerListening || _isShowingListeningModal) {
      micButtonChild = Icon(
        Icons.mic_off_rounded,
        color: Colors.redAccent,
      );
      micButtonPressed = _stopVoiceInput;
      micTooltip = 'Dừng ghi âm';
    } else {
      micButtonChild = Icon(
        Icons.mic_rounded,
        color: Theme.of(context).primaryColor,
      );
      micButtonPressed = _startVoiceInput;
      micTooltip = 'Bắt đầu ghi âm giọng nói';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot Hỗ Trợ'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off_rounded,
              color: _isConnected ? Colors.lightGreenAccent : Colors.redAccent,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24.0),
          child: Container(
            color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              _connectionStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _isConnected ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final messageData = _messages[index];
                return ChatMessageWidget(
                  text: messageData.text,
                  role: messageData.role,
                  timestamp: messageData.timestamp,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.12),
                )
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: micButtonChild,
                  onPressed: micButtonPressed,
                  tooltip: micTooltip,
                  iconSize: 28, // Đặt kích thước cố định cho icon
                  padding: EdgeInsets.all(12.0), // Tăng vùng chạm
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendTextMessage,
                  child: const Icon(Icons.send_rounded),
                  tooltip: 'Gửi tin nhắn',
                  elevation: 2.0,
                ),
              ],
            ),
          ),
          if (!_isConnected && !_isVoiceInputLoading) // Chỉ hiển thị nút khi không kết nối và không đang loading
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Thử kết nối lại"),
                onPressed: _connectWebSocket,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: TextStyle(fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }
}

// ChatMessageWidget (không thay đổi)
class ChatMessageWidget extends StatelessWidget {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  const ChatMessageWidget({
    Key? key,
    required this.text,
    required this.role,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isUserMessage = (role == MessageRole.user_typed || role == MessageRole.user_stt);
    String displayText = text;
    IconData? leadingIcon;
    CrossAxisAlignment messageAlignment = CrossAxisAlignment.start; // Mặc định cho chatbot
    Color bubbleColor = Colors.grey[200]!;
    Color textColor = Colors.black87;

    if (isUserMessage) {
      messageAlignment = CrossAxisAlignment.end; // Căn phải cho user
      bubbleColor = Theme.of(context).primaryColor.withOpacity(0.9);
      textColor = Colors.white;
      if (role == MessageRole.user_stt) {
        leadingIcon = Icons.mic_rounded;
      } else { // user_typed
        leadingIcon = Icons.person_rounded; // Hoặc null nếu không muốn icon cho tin nhắn gõ
      }
    } else { // Chatbot message
      leadingIcon = Icons.smart_toy_rounded;
    }

    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUserMessage ? const Radius.circular(20) : const Radius.circular(0),
            bottomRight: isUserMessage ? const Radius.circular(0) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, 1))
          ],
        ),
        child: Column(
          crossAxisAlignment: messageAlignment, // Dùng cho timestamp
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, // Để icon và text thẳng hàng
              children: [
                // Icon bên trái cho chatbot
                if (leadingIcon != null && !isUserMessage)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 1.0), // Điều chỉnh vị trí icon
                    child: Icon(leadingIcon, size: 18, color: Colors.black54),
                  ),
                Flexible(
                  child: Text(
                    displayText,
                    style: TextStyle(color: textColor, fontSize: 15.5, height: 1.3),
                  ),
                ),
                // Icon bên phải cho user
                if (leadingIcon != null && isUserMessage)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 1.0), // Điều chỉnh vị trí icon
                    child: Icon(leadingIcon, size: 18, color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('HH:mm').format(timestamp),
              style: TextStyle(
                fontSize: 10.5,
                color: isUserMessage ? Colors.white.withOpacity(0.7) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}