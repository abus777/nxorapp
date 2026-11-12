import SwiftUI
import Combine

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var code = ""
    @State private var step: Step = .email
    @State private var busy = false
    @State private var error: String?
    @State private var resendAt = Date()
    @State private var now = Date()
    @FocusState private var focus: Field?

    enum Step { case email, code }
    enum Field { case email, code }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var emailValid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 5
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NXLogo(size: 22).padding(.bottom, 56)

                switch step {
                case .email: emailStep
                case .code: codeStep
                }

                if let error {
                    Text(error)
                        .font(NX.F.body(14))
                        .foregroundStyle(NX.C.danger)
                        .padding(.top, 14)
                }

                Spacer(minLength: 40)

                Text("By continuing you agree to the NXOR Terms and Privacy Policy.")
                    .font(NX.F.body(13))
                    .foregroundStyle(NX.C.muted)
                    .padding(.top, 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                NX.C.bg
                SpectrumGlow().offset(y: 80)
            }
            .ignoresSafeArea()
        }
        .scrollDismissesKeyboard(.interactively)
        .onReceive(timer) { now = $0 }
        .onAppear { focus = .email }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetaLabel("Every engine. One chat.", color: NX.C.accent, size: 11).padding(.bottom, 14)
            Text("Ask, then\nrender.")
                .font(NX.F.display(44))
                .foregroundStyle(NX.G.heroInk)
                .padding(.bottom, 14)
            Text("Sign in with your email — we'll send a 6-digit code. No password.")
                .font(NX.F.body(16)).foregroundStyle(NX.C.ink2)
                .padding(.bottom, 36)

            MetaLabel("Email").padding(.bottom, 10)
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
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(NX.C.surface)
                .overlay(Rectangle().strokeBorder(focus == .email ? NX.C.line2 : NX.C.line, lineWidth: 1))
                .padding(.bottom, 16)

            NXPrimaryButton(title: busy ? "Sending…" : "Continue with email") { sendCode() }
                .disabled(!emailValid || busy)
                .opacity(emailValid ? 1 : 0.5)

            HStack(spacing: 12) {
                Hairline()
                MetaLabel("or")
                Hairline()
            }
            .padding(.vertical, 24)

            Button { model.enterDemo() } label: {
                Text("EXPLORE WITHOUT AN ACCOUNT")
                    .font(NX.F.mono(12, .semibold)).tracking(2.2)
                    .foregroundStyle(NX.C.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .overlay(CutCorner(cut: 12).strokeBorder(NX.C.line2, lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisplayTitle("Check your", size: 34)
            DisplayTitle("inbox.", size: 34).padding(.bottom, 12)
            Text("We sent a sign-in code to \(email). It expires in 15 minutes.")
                .font(NX.F.body(16)).foregroundStyle(NX.C.ink2)
                .padding(.bottom, 32)

            MetaLabel("6-digit code").padding(.bottom, 10)
            OTPField(code: $code)
                .focused($focus, equals: .code)
                .onChange(of: code) { _, new in
                    if new.count == 6 { verify() }
                }
                .padding(.bottom, 20)

            NXPrimaryButton(title: busy ? "Checking…" : "Verify & continue") { verify() }
                .disabled(code.count != 6 || busy)
                .opacity(code.count == 6 ? 1 : 0.5)

            HStack {
                let left = max(0, Int(resendAt.timeIntervalSince(now).rounded(.up)))
                Button(left > 0 ? "Resend in 0:\(String(format: "%02d", left))" : "Resend code") { sendCode() }
                    .disabled(left > 0 || busy)
                Spacer()
                Button("Change email") {
                    step = .email
                    code = ""
                    error = nil
                    focus = .email
                }
            }
            .font(NX.F.mono(12, .semibold))
            .tint(NX.C.ink2)
            .padding(.top, 20)
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
                    let active = i == chars.count
                    Text(i < chars.count ? String(chars[i]) : "")
                        .font(NX.F.mono(24, .semibold))
                        .foregroundStyle(NX.C.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NX.C.surface)
                        .overlay(Rectangle().strokeBorder(active ? NX.C.accent : NX.C.line, lineWidth: 1))
                }
            }
            .allowsHitTesting(false)
        }
    }
}
