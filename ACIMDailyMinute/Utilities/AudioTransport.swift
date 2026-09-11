import Foundation

/// Numbers the in-app player and `AudioManager.seek` both use.
///
/// A drag on the slider is a position in the file, not a guess made inside
/// `AVPlayer`. Pure Foundation so `tools/verify_audio_transport.sh` can
/// compile this file and nothing else.
enum AudioTransport {
    /// A place in the file. Non-finite values and an unknown duration collapse
    /// to 0 rather than NaN, which a slider would then refuse to draw.
    static func clampedPosition(_ position: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        if position.isNaN { return 0 }
        if position.isInfinite { return position > 0 ? duration : 0 }
        if position < 0 { return 0 }
        if position > duration { return duration }
        return position
    }

    /// 0...1 for a slider. Unknown duration is 0, never NaN.
    static func sliderFraction(position: Double, duration: Double) -> Double {
        let clamped = clampedPosition(position, duration: duration)
        guard duration.isFinite, duration > 0 else { return 0 }
        return clamped / duration
    }

    /// `m:ss`. Negative and non-finite become `0:00`.
    static func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Remaining time, prefixed with a minus so elapsed and remaining cannot
    /// be swapped at a glance.
    static func remainingLabel(position: Double, duration: Double) -> String {
        let left = clampedPosition(duration, duration: duration)
            - clampedPosition(position, duration: duration)
        return "-\(timeLabel(left))"
    }
}
