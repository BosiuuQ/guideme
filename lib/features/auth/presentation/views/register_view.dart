
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/presentation/widgets/custom_text_form_field_widget.dart';
import 'package:guide_me/core/presentation/widgets/unfocus_on_tap_wrapper.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/auth/register_auth.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hasła muszą być takie same')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final success = await RegisterAuth.registerUser(
          email: _loginController.text.trim(),
          password: _passwordController.text,
          nickname: _nicknameController.text.trim(),
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sprawdź swoją skrzynkę i kliknij w link weryfikacyjny')),
          );
          context.goNamed(AppRoutes.loginView);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnfocusOnTapWrapper(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          leadingWidth: 0,
          title: Image.asset(
            alignment: AlignmentDirectional.centerStart,
            AppAssets.logoImg,
            width: 100.0,
            height: 100.0,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height -
                        MediaQuery.paddingOf(context).bottom -
                        MediaQuery.paddingOf(context).top -
                        100,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 1),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: Text(
                                'Utwórz konto',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 48.0),
                            CustomTextFormFieldWidget(
                              label: "Nickname",
                              controller: _nicknameController,
                              maxLines: 1,
                              prefixIcon: const Icon(Icons.person, color: AppColors.lightBlue),
                              keyboardType: TextInputType.text,
                              hint: "Twój nickname",
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Uzupełnij nickname' : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextFormFieldWidget(
                              label: "Login",
                              controller: _loginController,
                              maxLines: 1,
                              prefixIcon: const Icon(Icons.email, color: AppColors.lightBlue),
                              keyboardType: TextInputType.emailAddress,
                              hint: "guideme@gmail.com",
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Uzupełnij login' : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextFormFieldWidget(
                              label: "Hasło",
                              controller: _passwordController,
                              obscureText: true,
                              maxLines: 1,
                              prefixIcon: const Icon(Icons.lock, color: AppColors.lightBlue),
                              keyboardType: TextInputType.text,
                              hint: "********",
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Uzupełnij hasło' : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextFormFieldWidget(
                              label: "Powtórz hasło",
                              controller: _confirmPasswordController,
                              obscureText: true,
                              maxLines: 1,
                              prefixIcon: const Icon(Icons.lock, color: AppColors.lightBlue),
                              keyboardType: TextInputType.text,
                              hint: "********",
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Uzupełnij hasło' : null,
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _register,
                              child: !_isLoading
                                  ? const Text('UTWÓRZ',
                                      style: TextStyle(fontWeight: FontWeight.bold))
                                  : const SizedBox(
                                      height: 24.0,
                                      width: 24.0,
                                      child: CircularProgressIndicator(color: AppColors.darkBlue),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("Masz już konto?", style: TextStyle(fontSize: 16.0)),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Zaloguj się!",
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              if (_isLoading) Container(color: Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }
}
