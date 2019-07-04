//
//  ViewController.m
//  语音识别
//
//  Created by 沈凯 on 2019/7/1.
//  Copyright © 2019 Ssky. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<SFSpeechRecognizerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *displayLabel;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@property (strong, nonatomic) SFSpeechRecognizer *speechRecognizer;
@property (strong, nonatomic) AVAudioEngine *audioEngine;
@property (strong, nonatomic) SFSpeechRecognitionTask *recognitionTask;
@property (strong, nonatomic) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (strong, nonatomic) AVAudioSession *audioSession;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    [self accessPermissions];
}

- (void)accessPermissions {
//    语音识别授权
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        
        BOOL isEnabled = NO;
        NSString *str;
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                isEnabled = NO;
                str = @"不支持录音";
                NSLog(@"结果未知 用户尚未进行选择");
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                isEnabled = NO;
                str = @"不支持录音";
                NSLog(@"用户未授权使用语音识别");
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                isEnabled = NO;
                str = @"不支持录音";
                NSLog(@"设备不支持语音识别功能");
                break;
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                isEnabled = YES;
                str = @"开始录音";
                NSLog(@"用户授权语音识别");
                break;
            default:
                break;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.recordButton.enabled = isEnabled;
            if (isEnabled) {
                [self.recordButton setTitle:str forState:UIControlStateNormal];
            }else {
                [self.recordButton setTitle:str forState:UIControlStateDisabled];
            }
        });
    }];
    
//    麦克风使用授权
    if ([self.audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
        [self.audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.recordButton.enabled = granted;
                if (granted) {
                    NSLog(@"麦克风授权");
                    [self.recordButton setTitle:@"开始录音" forState:UIControlStateNormal];
                }else {
                    NSLog(@"麦克风未授权");
                    [self.recordButton setTitle:@"麦克风未授权" forState:UIControlStateDisabled];
                }
            });
        }];
    }
}

- (IBAction)action:(UIButton *)sender {
    if (self.audioEngine.isRunning) {
        [self endRecording];
        [sender setTitle:@"正在停止" forState:UIControlStateDisabled];
    }else {
        [self startRecording];
        [sender setTitle:@"停止录音" forState:UIControlStateNormal];
    }
}

- (SFSpeechRecognizer *)speechRecognizer {
    if (!_speechRecognizer) {
        NSLocale *local = [[NSLocale alloc]initWithLocaleIdentifier:@"zh_CN"];
        
        _speechRecognizer = [[SFSpeechRecognizer alloc]initWithLocale:local];
        _speechRecognizer.delegate = self;
    }
    return _speechRecognizer;
}

- (AVAudioEngine *)audioEngine {
    if (!_audioEngine) {
        _audioEngine = [[AVAudioEngine alloc]init];
    }
    return _audioEngine;
}

- (AVAudioSession *)audioSession {
    if (!_audioSession) {
        _audioSession = [AVAudioSession sharedInstance];
        NSError *error;
        [_audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
        [_audioSession setMode:AVAudioSessionModeMeasurement error:&error];
        [_audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    }
    return _audioSession;
}

- (void)startRecording {
    if (_recognitionTask) {
        [_recognitionTask cancel];
        _recognitionTask = nil;
    }
    
    _recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc]init];
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    _recognitionRequest.shouldReportPartialResults = YES;
    _recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:_recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        BOOL isFinal = NO;
        if (result) {
            self.displayLabel.text = result.bestTranscription.formattedString;
            isFinal = result.isFinal;
        }
        
        if (error || isFinal) {
            [self.audioEngine stop];
            [inputNode removeTapOnBus:0];
            self.recognitionTask = nil;
            self.recognitionRequest = nil;
            self.recordButton.enabled = YES;
            [self.recordButton setTitle:@"开始录音" forState:UIControlStateNormal];
        }
    }];
    
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode removeTapOnBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        if (self.recognitionRequest) {
            [self.recognitionRequest appendAudioPCMBuffer:buffer];
        }
    }];
    
    NSError *error;
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:&error];
    self.displayLabel.text = @"正在录音。。。";
}

- (void)endRecording {
    [self.audioEngine stop];
    if (_recognitionRequest) {
        [_recognitionRequest endAudio];
    }
    
    if (_recognitionTask) {
        [_recognitionTask cancel];
        _recognitionTask = nil;
    }
    
    self.recordButton.enabled = NO;
    
    self.displayLabel.text = @"";
}

#pragma mark - SFSpeechRecognizerDelegate
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    
    if (available) {
        NSLog(@"开始录音");
        [self.recordButton setTitle:@"开始录音" forState:UIControlStateNormal];
    }else {
        NSLog(@"语音识别不可用");
        [self.recordButton setTitle:@"语音识别不可用" forState:UIControlStateDisabled];
    }
    self.recordButton.enabled = available;
}

@end
