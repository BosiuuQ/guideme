import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/presentation/widgets/custom_text_form_field_widget.dart';
import 'package:guide_me/core/presentation/widgets/unfocus_on_tap_wrapper.dart';
import 'package:guide_me/features/auth/login_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _login() async {
  if (_isLoading) return;
  FocusScope.of(context).unfocus();
  if (_formKey.currentState!.validate()) {
    setState(() {
      _isLoading = true;
    });
    try {
      final email = _loginController.text.trim();
      final password = _passwordController.text;

      final userData = await LoginAuth.loginUser(
        email: email,
        password: password,
      );

      // ✅ Zabezpieczenie po await
      if (!mounted) return;

      // ✅ Zapisz dane do secure storage
      await _secureStorage.write(key: 'email', value: email);
      await _secureStorage.write(key: 'password', value: password);

      if (!mounted) return;

      if (userData.isNotEmpty) {
        context.goNamed(AppRoutes.mainView);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}


  void _changePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _loginWithGoogle() {
    // TODO: Logika logowania przez Google
  }

  void _loginWithFacebook() {
    // TODO: Logika logowania przez Facebooka
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
                                'Logowanie',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 48.0),
                            CustomTextFormFieldWidget(
                              label: "Login",
                              controller: _loginController,
                              maxLines: 1,
                              prefixIcon: const Icon(
                                Icons.person,
                                color: AppColors.lightBlue,
                                size: 24,
                              ),
                              scrollPadding: const EdgeInsets.only(bottom: 80),
                              keyboardType: TextInputType.emailAddress,
                              hint: "guideme@gmail.com",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Uzupełnij login';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextFormFieldWidget(
                              label: "Hasło",
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              maxLines: 1,
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: AppColors.lightBlue,
                                size: 24,
                              ),
                              suffixIcon: GestureDetector(
                                onTap: _changePasswordVisibility,
                                child: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: AppColors.lightBlue,
                                  size: 24,
                                ),
                              ),
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              keyboardType: TextInputType.text,
                              hint: "********",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Uzupełnij hasło';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  context.pushNamed('resetPassword');
                                },
                                child: const Text(
                                  "Zapomniałem hasła?",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _login,
                              child: !_isLoading
                                  ? const Text(
                                      'ZALOGUJ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : const SizedBox(
                                      height: 24.0,
                                      width: 24.0,
                                      child: CircularProgressIndicator(
                                        color: AppColors.darkBlue,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 24),
                            const Center(
                              child: Text(
                                "lub za pomocą",
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _loginWithGoogle,
                                  icon: Image.asset(
                                    AppAssets.googleIcon,
                                    height: 20.0,
                                    width: 20.0,
                                  ),
                                  style: ButtonStyle(
                                    backgroundColor:
                                        const MaterialStatePropertyAll(
                                      Colors.white,
                                    ),
                                  ),
                                  label: const Text(
                                    'Google',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _loginWithFacebook,
                                  icon: const FaIcon(
                                    FontAwesomeIcons.facebook,
                                    color: Colors.blue,
                                  ),
                                  style: ButtonStyle(
                                    backgroundColor:
                                        const MaterialStatePropertyAll(
                                      Colors.white,
                                    ),
                                  ),
                                  label: const Text(
                                    'Facebook',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            "Nie masz jeszcze konta?",
                            style: TextStyle(fontSize: 16.0),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.pushNamed(AppRoutes.registerView);
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Utwórz je teraz!",
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.transparent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
