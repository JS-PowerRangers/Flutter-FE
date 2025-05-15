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
  IOWebSocketChannel? _channel; // Sử dụng IOWebSocketChannel cho mobile/desktop
  final List<ChatMessageData> _messages = [];

  bool _isConnected = false;
  String _connectionStatus = "Đang kết nối...";
  bool _isServerListening = false; // Trạng thái server có đang nghe STT không

  // Địa chỉ IP và port của Python WebSocket server
  // Thay thế 'localhost' bằng địa chỉ IP của Raspberry Pi nếu Flutter chạy trên thiết bị khác
  final String _webSocketUrl = 'ws://localhost:8765'; // Mặc định cho local
  // final String _webSocketUrl = 'ws://YOUR_RASPBERRY_PI_IP:8765'; // Khi server ở máy khác

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close(); // Đóng kết nối WebSocket khi widget bị hủy
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Hàm kết nối đến WebSocket server
  void _connectWebSocket() {
    setState(() {
      _connectionStatus = "Đang kết nối đến $_webSocketUrl...";
      _isConnected = false;
      _messages.clear(); // Xóa tin nhắn cũ khi kết nối lại
      _addSystemMessage("Đang thử kết nối đến server...");
    });

    try {
      // Sử dụng IOWebSocketChannel cho các ứng dụng không phải web
      _channel = IOWebSocketChannel.connect(Uri.parse(_webSocketUrl));
      setState(() {
        _isConnected = true;
        _connectionStatus = "Đã kết nối!";
        _addSystemMessage("Kết nối thành công!");
      });

      // Lắng nghe tin nhắn từ server
      _channel!.stream.listen(
            (data) {
          _handleWebSocketMessage(data);
        },
        onDone: () {
          setState(() {
            _isConnected = false;
            _isServerListening = false;
            _connectionStatus = "Đã ngắt kết nối.";
            _addSystemMessage("Server đã ngắt kết nối.");
          });
          print("WebSocket connection closed by server.");
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
            _isServerListening = false;
            _connectionStatus = "Lỗi kết nối: $error";
            _addSystemMessage("Lỗi kết nối WebSocket: $error");
          });
          print('WebSocket error: $error');
        },
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isServerListening = false;
        _connectionStatus = "Không thể kết nối: $e";
        _addSystemMessage("Không thể khởi tạo kết nối: $e");
      });
      print('Error initializing WebSocket connection: $e');
    }
  }

  // Hàm xử lý tin nhắn nhận được từ WebSocket server
  void _handleWebSocketMessage(dynamic data) {
    print('Raw data received from server: $data');
    try {
      final decodedData = jsonDecode(data as String);
      final event = decodedData['event'] as String?;

      if (event == null) {
        _addSystemMessage("Lỗi: Server gửi sự kiện không hợp lệ (event is null).");
        return;
      }

      switch (event) {
        case 'listening':
          setState(() {
            _isServerListening = true;
            _addSystemMessage("Server đang lắng nghe giọng nói...");
          });
          break;
        case 'chat_message':
          final roleString = decodedData['role'] as String?;
          final messageText = decodedData['message'] as String?;

          if (roleString != null && messageText != null) {
            MessageRole role;
            if (roleString == 'user_stt') {
              role = MessageRole.user_stt;
            } else if (roleString == 'chatbot') {
              role = MessageRole.chatbot;
            } else {
              print('Unknown role in chat_message: $roleString');
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
          print('Error from server: $errorMessage');
          _addSystemMessage("Lỗi từ Server: ${errorMessage ?? 'Không rõ lỗi'}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi từ Server: ${errorMessage ?? 'Không rõ lỗi'}')),
          );
          break;
        case 'stop_listening_ack':
          print("Received stop_listening_ack from server.");
          // _isServerListening sẽ được quản lý bởi nút bấm và event 'listening'
          break;
        default:
          print('Unknown event from server: $event');
          _addSystemMessage("Lỗi: Sự kiện không xác định từ server ($event).");
      }
    } catch (e) {
      print('Error decoding JSON from server: $e');
      _addSystemMessage("Lỗi xử lý dữ liệu từ server: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xử lý dữ liệu từ server.')),
      );
    }
    _scrollToBottom();
  }

  void _addChatMessage(String text, MessageRole role) {
    setState(() {
      _messages.add(ChatMessageData(
        text: text,
        role: role,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addSystemMessage(String text) {
    print("System Message: $text");
    // Cân nhắc hiển thị các thông báo này một cách tinh tế hơn trên UI
    // Ví dụ:
    // setState(() {
    //   _messages.add(ChatMessageData(
    //     text: "Hệ thống: $text",
    //     role: MessageRole.chatbot, // Tạm dùng role này hoặc tạo MessageRole.system
    //     timestamp: DateTime.now(),
    //   ));
    // });
    // _scrollToBottom();
  }

  void _startVoiceInput() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({'event': 'start_listening'}));
      // _isServerListening sẽ được cập nhật bởi event 'listening' từ server
      _addSystemMessage("Đã gửi yêu cầu bắt đầu ghi âm đến server.");
    } else {
      _showConnectionErrorSnackbar("Chưa kết nối đến server để bắt đầu ghi âm.");
    }
  }

  void _stopVoiceInput() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({'event': 'stop_listening'}));
      setState(() {
        _isServerListening = false; // Cập nhật UI ngay, server sẽ gửi 'stop_listening_ack'
      });
      _addSystemMessage("Đã gửi yêu cầu dừng ghi âm đến server.");
    } else {
      _showConnectionErrorSnackbar("Chưa kết nối đến server để dừng ghi âm.");
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      if (_channel != null && _isConnected) {
        _addChatMessage(text, MessageRole.user_typed); // Hiển thị tin nhắn người dùng gõ
        _channel!.sink.add(jsonEncode({'event': 'text_message', 'text': text}));
        _textController.clear();
      } else {
        _showConnectionErrorSnackbar("Chưa kết nối đến server để gửi tin nhắn.");
      }
    }
  }

  void _showConnectionErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
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
                  icon: Icon(
                    _isServerListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: _isServerListening ? Colors.redAccent : Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  onPressed: _isServerListening ? _stopVoiceInput : _startVoiceInput,
                  tooltip: _isServerListening ? 'Dừng yêu cầu ghi âm' : 'Yêu cầu ghi âm giọng nói',
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
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendTextMessage,
                  child: const Icon(Icons.send_rounded),
                  tooltip: 'Gửi tin nhắn',
                ),
              ],
            ),
          ),
          if (!_isConnected)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Thử kết nối lại"),
                onPressed: _connectWebSocket,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

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
    CrossAxisAlignment messageAlignment = CrossAxisAlignment.start;
    Color bubbleColor = Colors.grey[200]!;
    Color textColor = Colors.black87;

    if (isUserMessage) {
      messageAlignment = CrossAxisAlignment.end;
      bubbleColor = Theme.of(context).primaryColor.withOpacity(0.9);
      textColor = Colors.white;
      if (role == MessageRole.user_stt) {
        // Server sẽ gửi lại văn bản đã STT.
        // Nếu bạn muốn phân biệt rõ hơn, server có thể thêm prefix "[Bạn nói]:"
        // Hoặc client có thể thêm ở đây nếu server không làm.
        // Ví dụ: displayText = "[Bạn nói]: $text";
        leadingIcon = Icons.mic_rounded;
      } else {
        leadingIcon = Icons.person_rounded;
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
          crossAxisAlignment: messageAlignment,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null && !isUserMessage)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 1.0),
                    child: Icon(leadingIcon, size: 18, color: Colors.black54),
                  ),
                Flexible(
                  child: Text(
                    displayText,
                    style: TextStyle(color: textColor, fontSize: 15.5, height: 1.3),
                  ),
                ),
                if (leadingIcon != null && isUserMessage)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 1.0),
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