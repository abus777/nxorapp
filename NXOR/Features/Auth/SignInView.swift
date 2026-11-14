import SwiftUI
import Combine

/// R1: sign in — Apple first, then Google and email (6-digit code, no password).
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = .start
    @State private var email = ""
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @State private var resendAt = Date()
    @State private var now = Date()
    @State private var providerNote: String?
    @FocusState private var focus: Field?

    enum Step { case start, email, code }
    enum Field { case email, code }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var emailValid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 5
    }

    var body: some View {
        ZStack {
            BackgroundAura()
            VStack(spacing: 14) {
                switch step {
                case .start: start
                case .email: emailStep
                case .code: codeStep
                }
                if let error {
                    Text(error).font(NX.F.body(14)).foregroundStyle(NX.C.danger).multilineTextAlignment(.center)
                }
                HStack(spacing: 4) {
                    Text("By continuing you agree to the")
                    Link("Terms", destination: URL(string: "https://nxor.ai/legal/terms")!).underline()
                    Text("and")
                    Link("Privacy Policy", destination: URL(string: "https://nxor.ai/legal/privacy")!).underline()
                }
                .font(NX.F.body(11))
                .foregroundStyle(NX.C.ink3)
                .tint(NX.C.ink2)
            }
            .padding(20)
        }
        .onReceive(timer) { now = $0 }
        .alert("Coming soon", isPresented: Binding(get: { providerNote != nil }, set: { if !$0 { providerNote = nil } })) {
            Button("Use email") { step = .email; focus = .email }
            Button("OK", role: .cancel) {}
        } message: {
            Text(providerNote ?? "")
        }
    }

    private var start: some View {
        VStack(spacing: 14) {
            Spacer()
            NXMark().fill(NX.G.logo).frame(width: 60, height: 60).padding(.bottom, 10)
            Text("PICTURES, VIDEO AND ANSWERS FROM ONE PROMPT")
                .font(NX.F.display(26))
                .foregroundStyle(NX.C.inkSoft)
                .multilineTextAlignment(.center)
            Text("70+ AI models. NXOR picks the right one.")
                .font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
            Spacer()
            SkewButton(title: "Sign in with Apple", icon: "apple.logo", size: .l, style: .metal, fullWidth: true) {
                providerNote = "Sign in with Apple needs support on the NXOR server. Until then, sign in with your email — it takes a 6-digit code, no password."
            }
            SkewButton(title: "Continue with Google", size: .m, style: .dark, fullWidth: true) {
                providerNote = "Google sign-in needs support on the NXOR server. Until then, use your email."
            }
            SkewButton(title: "Continue with email", size: .m, style: .dark, fullWidth: true) {
                withAnimation(NX.Motion.pop) { step = .email }
                focus = .email
            }
            Button("Explore without an account") { model.enterDemo() }
                .font(NX.F.body(14)).underline().foregroundStyle(NX.C.inkSoft)
                .frame(minHeight: 44)
        }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            BackLink(title: "Back") { step = .start; error = nil }
            Spacer()
            Text("WELCOME BACK.").font(NX.F.display(30)).foregroundStyle(NX.C.inkSoft)
            Text("We'll send a 6-digit code. No password.").font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
            TextField("", text: $email, prompt: Text("you@example.com").foregroundColor(NX.C.muted))
                .font(NX.F.body(17))
                .foregroundStyle(NX.C.ink)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.continue)
                .onSubmit { sendCode() }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(NX.C.tint.opacity(0.06))
            SkewButton(title: busy ? "Sending…" : "Send code", size: .l, style: .metal, fullWidth: true, enabled: emailValid && !busy) { sendCode() }
            Spacer()
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            BackLink(title: "Change email") { step = .email; code = ""; error = nil; focus = .email }
            Spacer()
            Text("CHECK YOUR INBOX.").font(NX.F.display(30)).foregroundStyle(NX.C.inkSoft)
            Text("We sent a code to \(email). It expires in 15 minutes.").font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
            OTPField(code: $code)
                .focused($focus, equals: .code)
                .onChange(of: code) { _, new in if new.count == 6 { verify() } }
            SkewButton(title: busy ? "Checking…" : "Verify & continue", size: .l, style: .metal, fullWidth: true, enabled: code.count == 6 && !busy) { verify() }
            let left = max(0, Int(resendAt.timeIntervalSince(now).rounded(.up)))
            Button(left > 0 ? "Resend in 0:\(String(format: "%02d", left))" : "Resend code") { sendCode() }
                .disabled(left > 0 || busy)
                .font(NX.F.body(14)).foregroundStyle(NX.C.ink2).frame(minHeight: 44)
            Spacer()
        }
    }

    private func sendCode() {
        guard emailValid, !busy else { return }
        busy = true
        error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await NXORService.requestCode(email: email.trimmingCharacters(in: .whitespaces))
                step = .code
                resendAt = Date().addingTimeInterval(60)
                focus = .code
            } catch let e as APIError {
                error = e.errorDescription
                if let ms = e.retryAfterMs { resendAt = Date().addingTimeInterval(ms / 1000) }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func verify() {
        guard code.count == 6, !busy else { return }
        busy = true
        error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await NXORService.verifyCode(email: email.trimmingCharacters(in: .whitespaces), code: code)
                await model.didSignIn()
            } catch {
                self.error = (error as? APIError)?.status == 403 || (error as? APIError)?.status == 400
                    ? "That code didn't work. Check the latest email and try again."
                    : error.localizedDescription
                code = ""
            }
        }
    }
}

struct OTPField: View {
    @Binding var code: String

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .onChange(of: code) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(6))
                    if digits != new { code = digits }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let chars = Array(code)
                    Text(i < chars.count ? String(chars[i]) : "")
                        .font(NX.F.mono(24, .semibold))
                        .foregroundStyle(NX.C.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Parallelogram(slant: 0.12).fill(NX.C.tint.opacity(i == chars.count ? 0.14 : 0.06)))
                }
            }
            .allowsHitTesting(false)
        }
    }
}
