import 'dart:async';

import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'package:chatgpt/api_key.dart';
import 'package:chatgpt/model/question_answer.dart';
import 'package:chatgpt/theme.dart';
import 'package:chatgpt/view/components/chatgpt_answer_widget.dart';
import 'package:chatgpt/view/components/loading_widget.dart';
import 'package:chatgpt/view/components/text_input_widget.dart';
import 'package:chatgpt/view/components/user_question_widget.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? answer;
  final loadingNotifier = ValueNotifier<bool>(false);
  final List<QuestionAnswer> questionAnswers = [];

  late ScrollController scrollController;
  late ChatGpt chatGpt;
  late TextEditingController inputQuestionController;
  StreamSubscription<CompletionResponse>? streamSubscription;

  @override
  void initState() {
    inputQuestionController = TextEditingController();
    scrollController = ScrollController();
    chatGpt = ChatGpt(apiKey: openAIApiKey);
    super.initState();
  }

  @override
  void dispose() {
    inputQuestionController.dispose();
    loadingNotifier.dispose();
    scrollController.dispose();
    streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg500Color,
      appBar: AppBar(
        elevation: 1,
        shadowColor: Colors.white12,
        centerTitle: true,
        title: Text(
          "ChatGPT",
          style: kWhiteText.copyWith(fontSize: 20, fontWeight: kSemiBold),
        ),
        backgroundColor: kBg300Color,
      ),
      body: SafeArea(
        child: Column(
          children: [
            buildChatList(),
            TextInputWidget(
              textController: inputQuestionController,
              onSubmitted: () => _sendMessage(),
            )
          ],
        ),
      ),
    );
  }

  Expanded buildChatList() {
    return Expanded(
      child: ListView.separated(
        controller: scrollController,
        separatorBuilder: (context, index) => const SizedBox(
          height: 12,
        ),
        physics: const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.only(bottom: 20, left: 16, right: 16, top: 16),
        itemCount: questionAnswers.length,
        itemBuilder: (BuildContext context, int index) {
          final question = questionAnswers[index].question;
          final answer = questionAnswers[index].answer;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UserQuestionWidget(question: question),
              const SizedBox(height: 16),
              ValueListenableBuilder(
                valueListenable: loadingNotifier,
                builder: (_, bool isLoading, __) {
                  if (answer.isEmpty && isLoading) {
                    _scrollToBottom();
                    return const LoadingWidget();
                  } else {
                    return ChatGptAnswerWidget(
                      answer: answer.toString().trim(),
                    );
                  }
                },
              )
            ],
          );
        },
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
  }

  void _sendMessage() async {
    final question = inputQuestionController.text;
    inputQuestionController.clear();
    loadingNotifier.value = true;

    setState(() => questionAnswers
        .add(QuestionAnswer(question: question, answer: StringBuffer())));

    final detailedPrompt =
        '''
    Act as a professional and talented dream interpreter. 
    Please check the grammar of the input (the user's dream). 
    Interpret the dream in detail and always provide answers in Turkish.
    
    User input: ```$question```
    
    Please provide a detailed interpretation of the dream, considering the following aspects:
    1. Pay attention to the specific details provided in the dream.
    2. Explore the symbolism and potential meanings behind the dream elements.
    3. Consider any emotions or sensations experienced during the dream.
    4. Reflect on how the dream may relate to the user's waking life, emotions, or personal challenges.
    
    Additionally, you can refer to the book "İslami Kaynaklara Göre Büyük Rüya Tabirleri – İmam Nablusi" to enhance the interpretation with valuable insights from Islamic sources.
    
    Based on the input provided, generate a thorough and comprehensive interpretation that offers valuable insights and explanations.
    The output should always be in Turkish. $question
  ''';

    final testRequest = CompletionRequest(
      prompt: [detailedPrompt],
      stream: true,
      maxTokens: 1000,
      temperature: 1,
      // model: ChatGptModel.textGpt35Turbo,
      model: ChatGptModel.textDavinci003,
      // model: ChatGptModel.gpt_3_5_turbo,
      // model: ChatGptModel.davinci,
    );
    await _streamResponse(testRequest)
        .whenComplete(() => loadingNotifier.value = true);
  }

  Future _streamResponse(CompletionRequest request) async {
    streamSubscription?.cancel();
    try {
      final stream = await chatGpt.createCompletionStream(request);
      streamSubscription = stream?.listen((event) {
        if (event.streamMessageEnd) {
          streamSubscription?.cancel();
        } else {
          setState(() {
            questionAnswers.last.answer.write(event.choices?.first.text);
            _scrollToBottom();
          });
        }
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => questionAnswers.last.answer.write("error"));
    }
  }
}
