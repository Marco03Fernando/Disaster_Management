import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_warning_app/core/services/officer_auth_service.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/core/theme/app_theme.dart';
import 'package:hazard_warning_app/core/widgets/common_widgets.dart';
import 'package:hazard_warning_app/features/report_verification/widgets/report_widgets.dart';
import 'package:provider/provider.dart';

/// Shows [child] only to an authorized duty officer; otherwise the sign-in
/// form or an access message. Firestore rules enforce the same check
/// server-side, so this gate is for the UI, not the security boundary.
class OfficerAccessGate extends StatelessWidget {
  const OfficerAccessGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = context.select<AppState, OfficerSession>(
      (s) => s.officerSession,
    );
    return switch (session.status) {
      OfficerAccessStatus.authorized => child,
      OfficerAccessStatus.checking => const _GateScaffold(
        child: ReviewStateView(
          icon: Icons.shield_outlined,
          title: 'Checking officer access…',
          message: 'Confirming your duty officer permissions.',
          action: CircularProgressIndicator(),
        ),
      ),
      OfficerAccessStatus.signedOut => const _GateScaffold(
        child: _OfficerSignInForm(),
      ),
      OfficerAccessStatus.unauthorized || OfficerAccessStatus.error =>
        _GateScaffold(child: _AccessProblem(session: session)),
    };
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/officer/home');
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Officer sign-in',
              subtitle: 'Report verification is limited to duty officers',
              onBack: () => _leave(context),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _OfficerSignInForm extends StatefulWidget {
  const _OfficerSignInForm();

  @override
  State<_OfficerSignInForm> createState() => _OfficerSignInFormState();
}

class _OfficerSignInFormState extends State<_OfficerSignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().signInOfficer(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      // On success the gate swaps this form out once access is resolved.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = context.select<AppState, bool>((s) => s.online);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            if (!online) ...[
              const ReviewNotice.offline(
                message: 'Connect to the internet to sign in.',
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBadge(
                            icon: Icons.shield_outlined,
                            color: AppColors.severityHigh,
                            size: 52,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DMC duty officer',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign in with the account issued by DMC.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Work email',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter your work email'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        ReviewNotice.error(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      PrimaryActionButton(
                        label: 'Sign in',
                        icon: Icons.login_rounded,
                        busy: _busy,
                        onPressed: online ? _submit : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Officer accounts are created by a DMC administrator. '
                    'Accounts cannot be self-registered.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessProblem extends StatelessWidget {
  const _AccessProblem({required this.session});

  final OfficerSession session;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final isError = session.status == OfficerAccessStatus.error;
    return ReviewStateView(
      icon: isError ? Icons.cloud_off_rounded : Icons.gpp_bad_outlined,
      color: isError ? AppColors.offlineText : AppColors.severityHigh,
      title: isError ? 'Could not check access' : 'Not authorized',
      message:
          '${session.message ?? ''}\n\nSigned in as ${session.email ?? session.displayName ?? 'unknown account'}.',
      action: Column(
        children: [
          if (isError)
            PrimaryActionButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: state.refreshOfficerAccess,
            ),
          if (isError) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: state.signOutOfficer,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

/// Who is reviewing, with a sign-out action; shown on the report dashboard.
class OfficerIdentityBar extends StatelessWidget {
  const OfficerIdentityBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.officerSession;
    final demo = !state.enforcesOfficerAccess;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.badge_outlined,
            color: AppColors.primaryBlue,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName ?? 'Duty officer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  demo
                      ? 'Demo mode · sign-in applies when Firebase is connected'
                      : 'Signed in · ${session.email ?? 'duty officer'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!demo)
            TextButton.icon(
              onPressed: state.signOutOfficer,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
            ),
        ],
      ),
    );
  }
}
