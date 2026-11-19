import SwiftUI
import AVFoundation
import CoreImage
import CoreMedia
import UIKit
import Vision

// ============================================================
// S1 (gói camera tự dựng, SCAN-CARD-AUDIT mục 2.5 — anh duyệt
// 2026-11-18): CAMERA QUÉT TỰ DỰNG kiểu Microsoft Lens, thay
// đường vào của nút CHỤP. Lý do rời hộp đen VisionKit: trần
// của VNDocumentCameraViewController là cố định — không chỉnh
// được điểm lấy nét, ngưỡng phát hiện cạnh hay tiêu chí tự
// chụp (hồ sơ mục 2.2). Ở đây app tự cầm AVCaptureSession theo
// đúng cách AVFoundation thiết kế cho camera tự dựng:
//
//   - Thiết bị đích iPhone 18 Pro Max: camera góc rộng sau,
//     preset .photo, định dạng ảnh tĩnh lớn nhất thiết bị hỗ
//     trợ (48MP trên máy đích; máy yếu hơn tự lùi về định dạng
//     lớn nhất của nó — fallback an toàn, không khoá cứng số).
//   - iOS 26+: Deferred Start cho output ảnh/phân tích (mở
//     xem trước trước, output nặng khởi động sau) + Responsive
//     Capture (chụp chồng pha, không khoá màn trập). KHÔNG bật
//     Deferred Photo Delivery và Fast Capture Prioritization:
//     hai cơ chế đó trả ẢNH ĐẠI DIỆN (proxy) trước và hoàn
//     thiện sau NGOÀI tiến trình — đường đọc cần ảnh CUỐI toàn
//     chất lượng ngay trong tiến trình để OCR, proxy không đủ
//     chuẩn. Ghi rõ để cổng sau không "bật cho đủ bộ".
//   - Lấy nét: .continuousAutoFocus + .continuousAutoExposure
//     với điểm nét/điểm sáng bám TÂM TỨ GIÁC hoá đơn (đổi hệ
//     qua preview layer như mẫu AVFoundation của Apple); chạm
//     tay vào màn hình = điểm nét ưu tiên ~2,5 giây.
//   - Phân tích trực tiếp trên luồng video ~12 fps (tự hạ còn
//     ~5 fps khi máy nóng — thermalState): VNDetectDocument
//     SegmentationRequest trước, VNDetectRectanglesRequest
//     nới cho hoá đơn sau (qua FlatScan.detectDocumentQuad);
//     vẽ khung Lens trực tiếp lên xem trước; độ sắc nét vùng
//     tứ giác đo bằng LuminanceGrid của CaptureIntake trên
//     ngưỡng cổng chất lượng hiện hành (blurMin).
//   - TỰ CHỤP khi đủ ba điều kiện LIÊN TỤC ~0,9 giây: có tứ
//     giác ổn định (góc lệch <= 0,012) + đủ sắc nét + máy đã
//     hết đang lấy nét (isAdjustingFocus == false). Nút chụp
//     tay luôn hiện. Chụp nhiều trang kiểu Lens: chụp xong
//     dừng ở trạng thái chờ — anh chọn Chụp trang tiếp hoặc
//     Xong.
//   - Sau chụp: DetectLensSmudgeRequest (iOS 26+) ở mức CẢNH
//     BÁO NHẸ — nghi ống kính bẩn thì nhắc + cho bỏ trang chụp
//     lại; không bao giờ chặn hay tự xoá ảnh (xem FlatScan).
//
// Vòng đời: session chạy trên hàng đợi riêng, phân tích trên
// hàng đợi riêng — main thread chỉ nhận trạng thái đã chốt.
// Rời màn hình = dừng session + tắt torch + gỡ quan sát viên.
// Quyền camera: dùng NSCameraUsageDescription sẵn có; bị từ
// chối -> màn hình nói rõ + đường lùi về máy quét hệ thống.
// ============================================================

struct ScanCameraView: View {
    /// Trả MỌI trang đã chụp (theo thứ tự) khi anh bấm Xong.
    var onFinish: ([UIImage]) -> Void
    var onCancel: () -> Void
    /// Đường lùi khi camera tự dựng không dùng được trên máy
    /// này (không có camera / bị từ chối quyền): ScanView đổi
    /// sang DocumentCameraView của hệ thống trong cùng cover.
    var onFallbackToSystemScanner: () -> Void

    @StateObject private var controller = ReceiptCameraController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let message = controller.unavailableMessage {
                unavailableView(message: message)
            } else {
                CameraPreview(controller: controller)
                    .ignoresSafeArea()
                controls
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    // MARK: - Lớp điều khiển phủ lên xem trước

    private var controls: some View {
        VStack(spacing: DS.spaceM) {
            HStack {
                Button {
                    controller.stop()
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.55), in: Circle())
                }
                Spacer()
                if controller.torchAvailable {
                    Button {
                        controller.toggleTorch()
                    } label: {
                        Image(systemName: controller.torchOn
                              ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.headline)
                            .foregroundStyle(controller.torchOn
                                             ? Color.yellow : Color.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.55), in: Circle())
                    }
                }
            }

            Spacer()

            if controller.smudgeWarning {
                VStack(spacing: DS.spaceS) {
                    Label("Ảnh vừa chụp có dấu hiệu ống kính bẩn hoặc mờ — anh lau nhẹ ống kính rồi chụp lại trang này cho rõ chữ.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                    HStack(spacing: DS.spaceM) {
                        Button("Bỏ trang này, chụp lại") {
                            controller.discardLastPage()
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        Button("Vẫn giữ trang này") {
                            controller.resumeScanning()
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
                .padding(DS.spaceM)
                .background(Color.black.opacity(0.72),
                            in: RoundedRectangle(cornerRadius: 14))
            }

            Text(controller.statusText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.spaceL)
                .padding(.vertical, DS.spaceS)
                .background(Color.black.opacity(0.55), in: Capsule())

            if controller.phase == .paused {
                HStack(spacing: DS.spaceM) {
                    Button("Bỏ trang cuối") {
                        controller.discardLastPage()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(controller.pageCount == 0)
                    Spacer()
                    Button("Chụp trang tiếp") {
                        controller.resumeScanning()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    Button("Xong") {
                        finish()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.brand)
                }
            } else {
                HStack {
                    Text(controller.pageCount > 0
                         ? "Đã chụp \(controller.pageCount) trang"
                         : " ")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(width: 110, alignment: .leading)
                    Spacer()
                    Button {
                        controller.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                        }
                    }
                    .disabled(controller.captureInFlight
                              || controller.phase == .starting)
                    Spacer()
                    Button("Xong") {
                        finish()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.brand)
                    .frame(width: 110, alignment: .trailing)
                    .opacity(controller.pageCount > 0 ? 1 : 0)
                    .disabled(controller.pageCount == 0)
                }
            }
        }
        .padding(DS.spaceL)
    }

    private func finish() {
        let pages = controller.takePages()
        controller.stop()
        onFinish(pages)
    }

    private func unavailableView(message: String) -> some View {
        VStack(spacing: DS.spaceL) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
            Text(message)
                .font(.callout)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("Dùng máy quét của hệ thống") {
                controller.stop()
                onFallbackToSystemScanner()
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.brand)
            Button("Đóng") {
                controller.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding(DS.spaceL)
    }
}

// MARK: - Xem trước + khung Lens

/// UIView mang AVCaptureVideoPreviewLayer làm lớp gốc + một
/// CAShapeLayer vẽ khung tứ giác. Đổi hệ điểm Vision (gốc
/// dưới-trái) -> điểm thiết bị (gốc trên-trái) ->
/// layerPointConverted — đúng mẫu đổi hệ của AVFoundation.
final class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private let quadLayer = CAShapeLayer()
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        quadLayer.fillColor = UIColor.clear.cgColor
        quadLayer.lineWidth = 3
        quadLayer.strokeColor = UIColor.systemYellow.cgColor
        layer.addSublayer(quadLayer)
        addGestureRecognizer(UITapGestureRecognizer(
            target: self, action: #selector(handleTap(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        quadLayer.frame = bounds
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onTap?(gesture.location(in: self))
    }

    /// Vẽ khung từ 4 góc Vision; stable = khung xanh (điều kiện
    /// đang khép, sắp tự chụp), chưa ổn định = khung vàng.
    func updateQuad(points: [CGPoint]?, stable: Bool) {
        guard let points, points.count == 4 else {
            quadLayer.path = nil
            return
        }
        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let devicePoint = CGPoint(x: point.x, y: 1 - point.y)
            let layerPoint = previewLayer.layerPointConverted(
                fromCaptureDevicePoint: devicePoint)
            if index == 0 { path.move(to: layerPoint) }
            else { path.addLine(to: layerPoint) }
        }
        path.close()
        quadLayer.path = path.cgPath
        quadLayer.strokeColor = (stable ? UIColor.systemGreen
                                 : UIColor.systemYellow).cgColor
    }
}

struct CameraPreview: UIViewRepresentable {
    let controller: ReceiptCameraController

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = controller.session
        view.previewLayer.videoGravity = .resizeAspectFill
        controller.attachPreviewLayer(view.previewLayer)
        view.onTap = { [weak controller] point in
            controller?.handleTap(at: point)
        }
        controller.onQuadOverlayUpdate = { [weak view] points, stable in
            view?.updateQuad(points: points, stable: stable)
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}
}

// MARK: - Bộ điều khiển phiên camera

final class ReceiptCameraController: NSObject, ObservableObject,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCapturePhotoCaptureDelegate {

    enum Phase {
        case starting, searching, tracking, paused, unavailable
    }

    @Published var phase: Phase = .starting
    @Published var statusText: String = "Đang mở camera…"
    @Published var pageCount: Int = 0
    @Published var torchOn: Bool = false
    @Published var torchAvailable: Bool = false
    @Published var smudgeWarning: Bool = false
    @Published var captureInFlight: Bool = false
    @Published var unavailableMessage: String? = nil

    /// Session tạo ngay từ init để preview layer bám vào được
    /// trước khi cấu hình chạy trên hàng đợi riêng.
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "glkeeper.camera.session")
    private let analysisQueue = DispatchQueue(label: "glkeeper.camera.analysis")
    private let analysisCIContext = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    // N2 (kiểm duyệt vòng 2) + NHỎ-4 (vòng 1): bốn biến vòng
    // đời dưới đây bị chạm từ HAI phía — gán trên sessionQueue
    // (device/focusObservation/notificationTokens trong
    // configureAndRun) hoặc trên main (previewLayer qua
    // attachPreviewLayer), trong khi stop()/điểm đọc khác chạy
    // trên main/sessionQueue. Nay tất cả đi qua stateLock như
    // mọi trạng thái dùng chung khác của file: backing riêng +
    // accessor khoá (chỉ giữ khoá trong lúc chạm backing,
    // không gọi ra ngoài khi đang giữ khoá).
    private var _device: AVCaptureDevice?
    private var device: AVCaptureDevice? {
        get {
            stateLock.lock(); defer { stateLock.unlock() }
            return _device
        }
        set {
            stateLock.lock(); _device = newValue; stateLock.unlock()
        }
    }
    private weak var _previewLayer: AVCaptureVideoPreviewLayer?
    private var previewLayer: AVCaptureVideoPreviewLayer? {
        get {
            stateLock.lock(); defer { stateLock.unlock() }
            return _previewLayer
        }
        set {
            stateLock.lock(); _previewLayer = newValue
            stateLock.unlock()
        }
    }
    private var pages: [UIImage] = []
    private var started = false
    private var _focusObservation: NSKeyValueObservation?
    private var focusObservation: NSKeyValueObservation? {
        get {
            stateLock.lock(); defer { stateLock.unlock() }
            return _focusObservation
        }
        set {
            stateLock.lock(); _focusObservation = newValue
            stateLock.unlock()
        }
    }
    private var _notificationTokens: [NSObjectProtocol] = []
    private var notificationTokens: [NSObjectProtocol] {
        get {
            stateLock.lock(); defer { stateLock.unlock() }
            return _notificationTokens
        }
        set {
            stateLock.lock(); _notificationTokens = newValue
            stateLock.unlock()
        }
    }

    // LOGIC-1 (kiểm duyệt vòng 1+2): định danh trang cho lượt
    // kiểm ống kính bẩn — mỗi trang chụp xong nhận một sê-ri
    // tăng dần; Task kiểm mang theo sê-ri của trang nó kiểm và
    // kết quả chỉ được hạ cánh khi trang đó vẫn là trang cuối.
    // pageSerials chạy song song với pages (chỉ chạm trên main,
    // cùng nơi pages được sửa).
    private var pageSerials: [Int] = []
    private var nextPageSerial = 0
    private var smudgeTask: Task<Void, Never>?

    /// Cầu nối khung tứ giác sang lớp xem trước (CameraPreview
    /// gán khi dựng view). Gọi trên main.
    var onQuadOverlayUpdate: (([CGPoint]?, Bool) -> Void)?

    // Trạng thái dùng chung giữa các hàng đợi — khoá riêng.
    private let stateLock = NSLock()
    private var _analysisPaused = false
    private var _captureBusy = false
    // NHỎ-1 (kiểm duyệt vòng 1): khởi tạo FALSE — KVO
    // isAdjustingFocus đăng ký không có .initial nên trước sự
    // kiện nét đầu tiên chưa có bằng chứng máy đã yên nét; để
    // true là tự chụp có thể bắn trong lúc máy còn săn nét.
    // Phép đo sắc nét Laplacian độc lập trong cửa sổ ~0,9 giây
    // vẫn giữ nguyên vai trò điều kiện song song.
    private var _focusSettled = false
    private var isAnalysisPaused: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _analysisPaused
    }
    private func setAnalysisPaused(_ value: Bool) {
        stateLock.lock(); _analysisPaused = value; stateLock.unlock()
    }
    private var isCaptureBusy: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _captureBusy
    }
    private func setCaptureBusy(_ value: Bool) {
        stateLock.lock(); _captureBusy = value; stateLock.unlock()
    }
    private var focusSettled: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _focusSettled
    }
    private func setFocusSettled(_ value: Bool) {
        stateLock.lock(); _focusSettled = value; stateLock.unlock()
    }

    // Sổ sách phân tích — CHỈ chạm trên analysisQueue.
    private var lastAnalysisAt = Date.distantPast
    private var stableQuad: [CGPoint]?
    private var readySince: Date?

    // Sổ sách nét — chỉ chạm trên main.
    private var lastFocusCenter: CGPoint?
    private var userFocusOverrideUntil = Date.distantPast

    // MARK: Vòng đời

    func start() {
        guard !started else { return }
        started = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in self?.configureAndRun() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.sessionQueue.async { self.configureAndRun() }
                } else {
                    DispatchQueue.main.async {
                        self.setUnavailable(
                            "App chưa được phép dùng camera. Anh bật quyền Camera cho GL-Keeper trong Cài đặt của máy, hoặc dùng máy quét của hệ thống.")
                    }
                }
            }
        default:
            setUnavailable(
                "App chưa được phép dùng camera. Anh bật quyền Camera cho GL-Keeper trong Cài đặt của máy, hoặc dùng máy quét của hệ thống.")
        }
    }

    func stop() {
        guard started else { return }
        started = false
        invalidateSmudgeCheck()
        setAnalysisPaused(true)
        focusObservation?.invalidate()
        focusObservation = nil
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        notificationTokens = []
        let device = self.device
        let session = self.session
        sessionQueue.async {
            if let device, device.hasTorch, device.torchMode != .off,
               (try? device.lockForConfiguration()) != nil {
                device.torchMode = .off
                device.unlockForConfiguration()
            }
            if session.isRunning { session.stopRunning() }
        }
        if torchOn { torchOn = false }
    }

    private func setUnavailable(_ message: String) {
        phase = .unavailable
        unavailableMessage = message
        statusText = message
    }

    // MARK: Cấu hình phiên (chạy trên sessionQueue)

    private func configureAndRun() {
        // N1 (kiểm duyệt vòng 2): nhánh cấp quyền bất đồng bộ
        // trong start() xếp hàm này lên sessionQueue SAU khi
        // quyền được cấp — nếu stop() đã chạy trong lúc hộp
        // quyền còn treo (anh đóng cover rồi mới cấp quyền),
        // started đã về false: không dựng phiên cho view đã đi.
        guard started else { return }
        // NHỎ-5 (kiểm duyệt vòng 1): stop() để lại
        // _analysisPaused = true; đặt lại ở đây để một lần
        // start lại trên cùng controller (khi có đường quay lại
        // camera trong cùng cover) không rơi vào phiên chạy mà
        // phân tích câm.
        setAnalysisPaused(false)
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back)
        else {
            DispatchQueue.main.async {
                self.setUnavailable("Máy này không có camera sau để quét hoá đơn.")
            }
            return
        }
        self.device = device
        session.beginConfiguration()
        session.sessionPreset = .photo

        func fail(_ message: String) {
            session.commitConfiguration()
            DispatchQueue.main.async { self.setUnavailable(message) }
        }

        // N1 (kiểm duyệt vòng 3): chốt chống cộng TRÙNG khi
        // configureAndRun chạy lại trên cùng controller sau một
        // vòng start/stop — input/output đã có thì giữ nguyên,
        // không add lần hai (add trùng làm canAddInput trả
        // false và rẽ oan sang màn "không dùng được").
        if session.inputs.isEmpty {
            guard let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                fail("Không mở được camera sau của máy.")
                return
            }
            session.addInput(input)
        }
        if session.outputs.isEmpty {
            guard session.canAddOutput(photoOutput),
                  session.canAddOutput(videoOutput) else {
                fail("Camera của máy không hỗ trợ chế độ chụp này.")
                return
            }
            session.addOutput(photoOutput)
            session.addOutput(videoOutput)
        }

        // Định dạng ảnh tĩnh lớn nhất thiết bị hỗ trợ (48MP
        // trên máy đích) + mặc định nét/sáng liên tục bám giữa
        // khung — tất cả trong MỘT lần khoá cấu hình.
        var maxDims = CMVideoDimensions(width: 0, height: 0)
        var bestFormat: AVCaptureDevice.Format?
        for format in device.formats {
            for dims in format.supportedMaxPhotoDimensions
            where Int64(dims.width) * Int64(dims.height)
                    > Int64(maxDims.width) * Int64(maxDims.height) {
                maxDims = dims
                bestFormat = format
            }
        }
        if (try? device.lockForConfiguration()) != nil {
            if let bestFormat, device.activeFormat != bestFormat {
                device.activeFormat = bestFormat
            }
            // L2 (kiểm duyệt vòng 3): maxPhotoDimensions đọc lại
            // từ format ĐANG ACTIVE ngay sau khi đặt (trong cùng
            // khối khoá này) và chỉ áp khi khoá thành công. Áp vô
            // điều kiện từ format lớn nhất toàn cục là đường
            // crash có điều kiện: hợp đồng AVFoundation đòi giá
            // trị này thuộc supportedMaxPhotoDimensions của
            // activeFormat HIỆN HÀNH — lệch nhau (khoá trượt /
            // phiên chốt format khác) là NSInvalidArgument
            // Exception. Khoá trượt thì để mặc định của output.
            var activeMaxDims = CMVideoDimensions(width: 0, height: 0)
            for dims in device.activeFormat.supportedMaxPhotoDimensions
            where Int64(dims.width) * Int64(dims.height)
                    > Int64(activeMaxDims.width) * Int64(activeMaxDims.height) {
                activeMaxDims = dims
            }
            if activeMaxDims.width > 0 {
                photoOutput.maxPhotoDimensions = activeMaxDims
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            device.unlockForConfiguration()
        }
        photoOutput.maxPhotoQualityPrioritization = .quality

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)

        // iOS 26+: Deferred Start cho hai output phân tích/
        // chụp (xem trước chạy trước) + Responsive Capture.
        // Kiểm isDeferredStartSupported TRƯỚC khi bật — bật
        // trên output không hỗ trợ là ngoại lệ cứng của hệ
        // thống. Deferred Photo Delivery + Fast Capture
        // Prioritization cố ý KHÔNG bật (xem đầu file).
        if #available(iOS 26, *) {
            if photoOutput.isDeferredStartSupported {
                photoOutput.isDeferredStartEnabled = true
            }
            if videoOutput.isDeferredStartSupported {
                videoOutput.isDeferredStartEnabled = true
            }
            if photoOutput.isResponsiveCaptureSupported {
                photoOutput.isResponsiveCaptureEnabled = true
            }
        }

        applyRotation(photoOutput.connection(with: .video))
        applyRotation(videoOutput.connection(with: .video))
        if let layer = previewLayer {
            applyRotation(layer.connection)
        }
        session.commitConfiguration()

        // Theo dõi máy còn đang lấy nét hay đã yên (một trong
        // ba điều kiện tự chụp). Chốt đăng-ký-một-lần (cùng họ
        // N1 vòng 3): chạy lại configureAndRun trên cùng
        // controller không đăng ký chồng — stop() đã gỡ và đưa
        // hai thứ này về rỗng nên lần start thật vẫn đăng ký lại.
        if focusObservation == nil {
            focusObservation = device.observe(\.isAdjustingFocus,
                                              options: [.new]) {
                [weak self] observedDevice, _ in
                self?.setFocusSettled(!observedDevice.isAdjustingFocus)
            }
        }
        if notificationTokens.isEmpty {
            registerSessionNotifications()
        }

        DispatchQueue.main.async {
            self.torchAvailable = device.hasTorch
            self.phase = .searching
            self.statusText = "Đưa hoá đơn vào khung — app tự tìm tờ giấy."
        }
        session.startRunning()
    }

    private func registerSessionNotifications() {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session, queue: .main) { [weak self] _ in
            self?.setStatus("Camera đang bị gián đoạn (cuộc gọi hoặc app khác) — xong việc đó camera sẽ chạy tiếp.")
        })
        notificationTokens.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.setStatus("Đưa hoá đơn vào khung — app tự tìm tờ giấy.")
            self.sessionQueue.async {
                if !self.session.isRunning { self.session.startRunning() }
            }
        })
        notificationTokens.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.setStatus("Camera gặp lỗi — đang mở lại…")
            self.sessionQueue.async {
                if !self.session.isRunning { self.session.startRunning() }
            }
        })
    }

    private func setStatus(_ text: String) {
        if statusText != text { statusText = text }
    }

    private func applyRotation(_ connection: AVCaptureConnection?) {
        guard let connection,
              connection.isVideoRotationAngleSupported(90) else { return }
        connection.videoRotationAngle = 90
    }

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        // Xem trước KHÔNG trì hoãn khởi động (Deferred Start
        // chỉ dành cho các output phía sau).
        if #available(iOS 26, *) {
            layer.isDeferredStartEnabled = false
        }
        applyRotation(layer.connection)
    }

    // MARK: Phân tích luồng video (analysisQueue)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if isAnalysisPaused || isCaptureBusy { return }
        let now = Date()
        // ~12 fps trên máy mát; máy nóng (.serious trở lên)
        // hạ còn ~5 fps để giữ nhịp lâu dài (thiết kế hồ sơ).
        let interval: TimeInterval
            = (ProcessInfo.processInfo.thermalState == .serious
               || ProcessInfo.processInfo.thermalState == .critical)
            ? 0.2 : (1.0 / 12.0)
        if now.timeIntervalSince(lastAnalysisAt) < interval { return }
        lastAnalysisAt = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return }
        let scale = min(1.0, 640.0 / max(extent.width, extent.height))
        let scaled = scale < 1.0
            ? ciImage.transformed(by: CGAffineTransform(scaleX: scale,
                                                        y: scale))
            : ciImage
        guard let cg = analysisCIContext.createCGImage(scaled,
                                                       from: scaled.extent)
        else { return }

        guard let obs = FlatScan.detectDocumentQuad(in: cg) else {
            stableQuad = nil
            readySince = nil
            DispatchQueue.main.async { [weak self] in
                self?.updateTracking(quad: nil, stableSeconds: 0)
            }
            return
        }
        let corners = [obs.topLeft, obs.topRight,
                       obs.bottomRight, obs.bottomLeft]

        // Độ sắc nét vùng tứ giác trên lưới sáng hạ mẫu, so với
        // ngưỡng cổng chất lượng hiện hành SAU CHUẨN HOÁ — L1
        // (kiểm duyệt vòng 3): bản cũ so phương sai Laplacian
        // THÔ thẳng với blurMin, trong khi blurMin được hiệu
        // chuẩn (2026-11-15) trên thang đã chuẩn hoá của
        // CaptureIntake.signals(): blur = blurThô x
        // downsampleFactor^blurScaleExponent. Nay áp ĐÚNG công
        // thức đó với downsampleFactor THẬT của lưới này: lưới
        // dựng từ khung video đã hạ mẫu (cạnh dài <= 640px) về
        // lưới 512 nên hệ số của lưới tự suy ra ~1,25 (hệ số
        // chuẩn hoá ~1,02) — xem mục "Sửa theo kiểm duyệt"
        // trong S1S2-DIFF.md cho phần chênh vật liệu nguồn còn
        // chờ cổng đo trên máy thật.
        var sharpOK = false
        if let grid = LuminanceGrid.fromImage(cg) {
            let xs = corners.map { Double($0.x) }
            let ys = corners.map { Double($0.y) }
            let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
            let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
            let box = CGRect(x: minX, y: minY,
                             width: maxX - minX, height: maxY - minY)
            if box.width * box.height >= 0.08 {
                let thresholds = QualityThresholds.current()
                let blur = grid.laplacianVariance(box)
                    * pow(grid.downsampleFactor,
                          thresholds.blurScaleExponent)
                sharpOK = blur >= thresholds.blurMin
            }
        }

        // Ổn định: góc lệch so với tứ giác mở cửa sổ <= 0,012
        // thì cửa sổ giữ nguyên; lệch hơn là mở cửa sổ mới.
        var driftOK = false
        if let reference = stableQuad {
            let drift = zip(corners, reference).map { current, ref in
                hypot(Double(current.x - ref.x), Double(current.y - ref.y))
            }.max() ?? 1
            if drift <= 0.012 { driftOK = true }
            else { stableQuad = corners }
        } else {
            stableQuad = corners
        }
        // Cửa sổ ~0,9 giây chỉ chạy khi ĐỒNG THỜI ổn định +
        // đủ sắc nét; mất một trong hai là đặt lại từ đầu.
        if driftOK && sharpOK {
            if readySince == nil { readySince = now }
        } else {
            readySince = nil
        }
        let stableSeconds = readySince.map {
            now.timeIntervalSince($0)
        } ?? 0
        DispatchQueue.main.async { [weak self] in
            self?.updateTracking(quad: corners,
                                 stableSeconds: stableSeconds)
        }
    }

    /// Hạ cánh kết quả phân tích trên main: vẽ khung, cập
    /// nhật trạng thái, bám điểm nét theo tâm tứ giác, và TỰ
    /// CHỤP khi cửa sổ điều kiện đã đủ ~0,9 giây + máy đã hết
    /// đang lấy nét.
    private func updateTracking(quad: [CGPoint]?, stableSeconds: Double) {
        guard unavailableMessage == nil, phase != .paused else { return }
        onQuadOverlayUpdate?(quad, stableSeconds > 0)
        guard let quad else {
            if phase != .searching { phase = .searching }
            setStatus("Đưa hoá đơn vào khung — app tự tìm tờ giấy.")
            return
        }
        if phase != .tracking { phase = .tracking }
        setStatus(stableSeconds >= 0.45
                  ? "Giữ yên… đủ nét là app tự chụp."
                  : "Đã thấy hoá đơn — giữ yên máy, đủ nét app tự chụp.")
        updateFocusPoint(for: quad)
        if stableSeconds >= 0.9, focusSettled, !isCaptureBusy {
            capturePhoto()
        }
    }

    /// Điểm nét/điểm sáng bám tâm tứ giác hoá đơn: đổi hệ
    /// Vision -> điểm thiết bị -> điểm lớp xem trước -> điểm
    /// quan tâm của thiết bị (đúng chuỗi đổi hệ AVFoundation).
    /// Chỉ đặt lại khi tâm đã dịch > 0,02 để camera khỏi "săn"
    /// nét liên tục; điểm anh chạm tay thắng trong ~2,5 giây.
    private func updateFocusPoint(for quad: [CGPoint]) {
        if Date() < userFocusOverrideUntil { return }
        let cx = quad.reduce(0.0) { $0 + Double($1.x) } / 4
        let cy = quad.reduce(0.0) { $0 + Double($1.y) } / 4
        if let last = lastFocusCenter,
           hypot(cx - Double(last.x), cy - Double(last.y)) < 0.02 {
            return
        }
        lastFocusCenter = CGPoint(x: cx, y: cy)
        guard let layer = previewLayer else { return }
        let devicePoint = CGPoint(x: cx, y: 1 - cy)
        let layerPoint = layer.layerPointConverted(
            fromCaptureDevicePoint: devicePoint)
        let poi = layer.captureDevicePointOfInterestForPoint(layerPoint)
        setFocusPOI(poi)
    }

    private func setFocusPOI(_ poi: CGPoint) {
        guard let device,
              (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = poi
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = poi
        }
        if device.isFocusModeSupported(.continuousAutoFocus),
           device.focusMode != .continuousAutoFocus {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure),
           device.exposureMode != .continuousAutoExposure {
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()
    }

    /// Chạm tay vào xem trước: điểm nét ưu tiên của anh.
    func handleTap(at point: CGPoint) {
        guard let layer = previewLayer, device != nil else { return }
        let poi = layer.captureDevicePointOfInterestForPoint(point)
        userFocusOverrideUntil = Date().addingTimeInterval(2.5)
        lastFocusCenter = nil
        setFocusPOI(poi)
    }

    // MARK: Chụp

    /// Chụp một trang (tự chụp và nút tay dùng chung). Điều
    /// kiện: session đang chạy + không có lượt chụp đang bay.
    func capturePhoto() {
        guard session.isRunning, !isCaptureBusy else { return }
        setCaptureBusy(true)
        captureInFlight = true
        setStatus("Đang chụp…")
        let settings = AVCapturePhotoSettings()
        if photoOutput.maxPhotoDimensions.width > 0 {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        }
        settings.photoQualityPrioritization = .quality
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let image: UIImage? = error == nil
            ? photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
            : nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setCaptureBusy(false)
            self.captureInFlight = false
            self.onQuadOverlayUpdate?(nil, false)
            guard let image else {
                self.phase = .searching
                self.setStatus("Chụp chưa thành — anh thử lại giúp.")
                self.resetStability()
                return
            }
            self.pages.append(image)
            self.nextPageSerial += 1
            self.pageSerials.append(self.nextPageSerial)
            self.pageCount = self.pages.count
            self.phase = .paused
            self.setAnalysisPaused(true)
            self.setStatus("Đã chụp \(self.pages.count) trang.")
            self.runSmudgeCheck(for: image,
                                pageSerial: self.nextPageSerial)
        }
    }

    /// Cảnh báo ống kính bẩn sau chụp — chạy nền, chỉ BẬT CỜ
    /// hiển thị; anh quyết giữ hay bỏ trang (xem ScanCameraView).
    /// LOGIC-1 (kiểm duyệt vòng 1+2): hạ cánh CÓ ĐIỀU KIỆN —
    /// Task mang sê-ri của trang nó kiểm; cờ chỉ bật khi trang
    /// đó VẪN là trang cuối hiện tại VÀ phase còn .paused.
    /// Bản cũ bật vô điều kiện: kết quả của trang N (chạy trên
    /// ảnh toàn phân giải, về muộn) có thể hạ cánh sau khi anh
    /// đã chụp trang N+1 — banner ám chỉ sai trang và nút "Bỏ
    /// trang này" sẽ xoá nhầm trang tốt. resume/discard/finish/
    /// stop đều huỷ Task đang bay qua invalidateSmudgeCheck().
    private func runSmudgeCheck(for image: UIImage, pageSerial: Int) {
        smudgeTask?.cancel()
        guard let cg = ReceiptReader.uprightCGImage(from: image)
        else { return }
        smudgeTask = Task { [weak self] in
            let confidence = await FlatScan.lensSmudgeConfidence(for: cg)
            guard let confidence, confidence > 0.9 else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self,
                      self.pageSerials.last == pageSerial,
                      self.phase == .paused else { return }
                self.smudgeWarning = true
            }
        }
    }

    /// Huỷ lượt kiểm ống kính bẩn đang bay — trang nó kiểm đã
    /// không còn là trang cuối (chụp tiếp / bỏ trang / xong /
    /// đóng màn) nên kết quả của nó không còn trang để ám chỉ.
    private func invalidateSmudgeCheck() {
        smudgeTask?.cancel()
        smudgeTask = nil
    }

    // MARK: Hành động sau chụp

    /// Chụp tiếp trang sau: dọn cửa sổ ổn định, mở lại phân tích.
    func resumeScanning() {
        invalidateSmudgeCheck()
        smudgeWarning = false
        resetStability()
        setAnalysisPaused(false)
        phase = .searching
        setStatus("Đưa hoá đơn vào khung — app tự tìm tờ giấy.")
    }

    /// Bỏ trang vừa chụp (dùng cả cho ca cảnh báo ống kính bẩn).
    func discardLastPage() {
        guard !pages.isEmpty else { return }
        invalidateSmudgeCheck()
        pages.removeLast()
        pageSerials.removeLast()
        pageCount = pages.count
        resumeScanning()
    }

    /// Lấy toàn bộ trang đã chụp để ScanView lưu + đọc; bộ
    /// nhớ đệm trang được dọn (cover đóng ngay sau đó).
    func takePages() -> [UIImage] {
        invalidateSmudgeCheck()
        let result = pages
        pages = []
        pageSerials = []
        pageCount = 0
        return result
    }

    private func resetStability() {
        analysisQueue.async { [weak self] in
            self?.stableQuad = nil
            self?.readySince = nil
        }
    }

    // MARK: Đèn pin

    func toggleTorch() {
        guard let device, device.hasTorch else { return }
        let target: AVCaptureDevice.TorchMode = torchOn ? .off : .on
        guard device.isTorchModeSupported(target),
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = target
        device.unlockForConfiguration()
        torchOn = target == .on
    }
}
