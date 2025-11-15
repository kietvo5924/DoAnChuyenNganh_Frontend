// lib/presentation/features/chatbot/pages/chatbot_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/injection.dart';
import 'package:planmate_app/presentation/features/chatbot/bloc/chatbot_bloc.dart';
import 'package:planmate_app/presentation/features/chatbot/bloc/chatbot_event.dart';
import 'package:planmate_app/presentation/features/chatbot/bloc/chatbot_state.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastHistoryLength = 0;
  bool _showJumpToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final atBottom = (max - offset) < 48; // within 48px of bottom
    if (_showJumpToBottom == atBottom) {
      setState(() => _showJumpToBottom = !atBottom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool instant = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent + 80;
    if (instant) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<ChatbotBloc>(), // keep singleton bloc, do not close on pop
      child: WillPopScope(
        onWillPop: () async {
          Navigator.of(context).pop(true); // notify previous to reload
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Trợ lý AI'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(true),
              tooltip: 'Quay lại',
            ),
          ),
          body: SafeArea(
            child: BlocConsumer<ChatbotBloc, ChatbotState>(
              listener: (context, state) {
                if (state.history.length != _lastHistoryLength) {
                  _lastHistoryLength = state.history.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }
              },
              builder: (context, state) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                final sysBottom = MediaQuery.of(context).padding.bottom;
                return Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            itemCount: state.history.length,
                            itemBuilder: (context, index) {
                              final message = state.history[index];
                              final isUser = message.role == 'user';
                              return Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? Colors.blue[100]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(message.content),
                                ),
                              );
                            },
                          ),
                        ),
                        if (state.status == ChatbotStatus.loading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: SizedBox(
                              height: 28,
                              width: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.only(
                            left: 8,
                            right: 8,
                            top: 6,
                            bottom:
                                (bottomInset > 0 ? bottomInset : 8) + sysBottom,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (val) {
                                    final text = val.trim();
                                    if (text.isEmpty) return;
                                    context.read<ChatbotBloc>().add(
                                      SendChatMessageEvent(text),
                                    );
                                    _controller.clear();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Nhập tin nhắn...',
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    final text = _controller.text.trim();
                                    if (text.isNotEmpty) {
                                      context.read<ChatbotBloc>().add(
                                        SendChatMessageEvent(text),
                                      );
                                      _controller.clear();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_showJumpToBottom)
                      Positioned(
                        right: 12,
                        bottom:
                            (bottomInset > 0 ? bottomInset : 8) +
                            sysBottom +
                            64,
                        child: FloatingActionButton.small(
                          elevation: 1,
                          onPressed: () => _scrollToBottom(),
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
