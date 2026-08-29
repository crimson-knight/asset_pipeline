// speech_bridge.m — portable AVSpeechSynthesizer (text-to-speech) bridge.
//
// Same rationale as notifications_bridge.m: objc_bridge.m is a UIKit/AppKit view
// bridge that can't compile on watchOS, but AVFoundation (AVSpeechSynthesizer) IS
// available on watchOS. This TU imports ONLY Foundation + AVFoundation, so it
// compiles for macOS, iOS, AND watchOS. The watch build compiles THIS file; the
// macOS/iOS native builds keep their copies in objc_bridge.m and do NOT compile
// this one, so the ap_speech_* symbols are never co-linked (no duplicate symbol).
//
// Requires -framework AVFoundation at app link.
//
// Compile (watchOS simulator):
//   clang -c src/ui/native/speech_bridge.m -o speech_bridge.o \
//     -arch arm64 -isysroot $(xcrun --sdk watchsimulator --show-sdk-path) \
//     -mwatchos-simulator-version-min=10.0 -fno-objc-arc

#include <stdlib.h>
#include <string.h>
#include <TargetConditionals.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

static NSString *ap_sb_string_from_cstr(const char *value) {
    if (!value || !value[0]) return nil;
    return [NSString stringWithUTF8String:value];
}

// One retained synthesizer for the process — a per-call instance can be
// deallocated mid-utterance and cut the speech off.
static AVSpeechSynthesizer *ap_speech_synth(void) {
    static AVSpeechSynthesizer *synth = nil;
    if (!synth) synth = [[AVSpeechSynthesizer alloc] init];
    return synth;
}

// iOS/watchOS require an active playback audio session before speech is audible.
// (macOS has no AVAudioSession. This TU is normally compiled only for watch, but
// the guard keeps it portable in case a future cleanup compiles it everywhere.)
static void ap_speech_activate_session(void) {
#if !TARGET_OS_OSX
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if (!session) return;
    [session setCategory:AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeSpokenAudio
                 options:AVAudioSessionCategoryOptionDuckOthers
                   error:nil];
    [session setActive:YES error:nil];
#endif
}

int ap_speech_speak(const char *text_cstr, double rate, double pitch, double volume, const char *lang_cstr) {
    NSString *text = ap_sb_string_from_cstr(text_cstr);
    if (!text || !text.length) return 0;

    AVSpeechSynthesizer *synth = ap_speech_synth();
    if (!synth) return 0;

    ap_speech_activate_session();

    AVSpeechUtterance *utt = [AVSpeechUtterance speechUtteranceWithString:text];
    utt.rate = (float)rate;
    utt.pitchMultiplier = (float)pitch;
    utt.volume = (float)volume;
    NSString *lang = ap_sb_string_from_cstr(lang_cstr);
    if (lang && lang.length) {
        AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:lang];
        if (voice) utt.voice = voice;
    }

    [synth speakUtterance:utt];
    return 1; // enqueued; speech starts asynchronously — caller queries is_speaking
}

void ap_speech_stop(void) {
    AVSpeechSynthesizer *synth = ap_speech_synth();
    [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

int ap_speech_is_speaking(void) {
    AVSpeechSynthesizer *synth = ap_speech_synth();
    return synth.isSpeaking ? 1 : 0;
}
