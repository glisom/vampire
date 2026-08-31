import Darwin
import InsomniaShared
import OSLog

let logger = Logger(subsystem: AppConstants.appBundleID, category: "helper")
let runner = ProcessCommandRunner()
let hardware = MacBookHardwareSupport()
let powerSettings = PMSetController(runner: runner, hardware: hardware)
let markerStore = FileRecoveryMarkerStore(markerURL: AppConstants.recoveryMarker)
let controller = HelperController(powerSettings: powerSettings, markerStore: markerStore)
_ = controller.normalizeAtStartup()

do {
    try HelperListener(controller: controller).start()
} catch {
    logger.error("The helper listener could not start: \(String(describing: error), privacy: .public)")
    exit(EXIT_FAILURE)
}
