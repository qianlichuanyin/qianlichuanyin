//
//  CWVoiceChangePlayView.m
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWVoiceChangePlayView.h"
#import "UIView+CWChat.h"
#import "CWVoiceChangePlayCell.h"
#import "CWAudioPlayer.h"
#import "CWRecordModel.h"
#import "QLCWVoiceView.h"
#import "CWRecorder.h"
#import "CWFlieManager.h"
#import "zyprotocol.h"
#import <QMUIKit/QMUIKit.h>
#import "QLglobalvar.h"
#import <AFHTTPSessionManager+Synchronous.h>
#import "CWRecordStateView.h"

@interface CWVoiceChangePlayView()

@property (nonatomic, weak) UIButton *cancelButton; // 取消按钮
@property (nonatomic, weak) UIButton *sendButton;   // 发送按钮

@property (nonatomic,strong) CADisplayLink *playTimer;      // 播放时振幅计时器

@property (nonatomic,weak) CWVoiceChangePlayCell *playingView;

@property (nonatomic,strong) NSMutableArray *imageNames;

@property (nonatomic,weak) UIScrollView *contentScrollView;

@property(nonatomic, strong)QLTPAACAudioConverter* audioconverter;
@end

@implementation CWVoiceChangePlayView

#pragma mark - lazyLoad
- (NSMutableArray *)imageNames {
    if (_imageNames == nil) {
        _imageNames = [NSMutableArray array];
        for (int i = 0; i < 6; i++) {
            [_imageNames addObject:[NSString stringWithFormat:@"aio_voiceChange_effect_%d",i]];
        }
    }
    return _imageNames;
}


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    [self setupContentScrollView];
    [self setupSendButtonAndCancelButton];
}
#pragma mark - setupUI
- (void)setupContentScrollView {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    scrollView.backgroundColor = [UIColor whiteColor];
    scrollView.bounces = YES;
    scrollView.cw_height = scrollView.cw_height - 40;
    scrollView.showsVerticalScrollIndicator = NO;
    [self addSubview:scrollView];
    self.contentScrollView = scrollView;
    
    NSArray *titles = @[@"原声",@"萝莉",@"大叔",@"惊悚",@"空灵",@"搞怪"];
    CGFloat width = self.cw_width / 4;
    CGFloat height = width + 10;
    __weak typeof(self) weakSelf = self;
    for (int i = 0; i < self.imageNames.count; i++) {
        CWVoiceChangePlayCell *cell = [[CWVoiceChangePlayCell alloc] initWithFrame:CGRectMake(i%4 * width, i / 4 * height, width, height)];
        cell.center = scrollView.center;
        cell.imageName = self.imageNames[i];
        cell.title = titles[i];
        [self.contentScrollView addSubview:cell];
        [UIView animateWithDuration:0.25 animations:^{
            cell.frame = CGRectMake(i%4 * width, i / 4 * height, width, height);
        } completion:^(BOOL finished) {
            cell.frame = CGRectMake(i%4 * width, i / 4 * height, width, height);
        }];
        cell.playRecordBlock = ^(CWVoiceChangePlayCell *cellBlock) {
            [weakSelf.playTimer invalidate];
            if (weakSelf.playingView != cellBlock) {
                [weakSelf.playingView endPlay];
            }
            [cellBlock playingRecord];
            weakSelf.playingView = cellBlock;
            [weakSelf startPlayTimer];
        };
        cell.endPlayBlock = ^(CWVoiceChangePlayCell *cellBlock) {
            [weakSelf.playTimer invalidate];
            [cellBlock endPlay];
        };
        if (i == self.imageNames.count - 1) {
            CGFloat h = i / 4 * height;
            if (h < self.cw_height - self.cancelButton.cw_height) h = self.cw_height - self.cancelButton.cw_height + 1;
            self.contentScrollView.contentSize = CGSizeMake(0, h);
        }
    }
    
}


- (void)setupSendButtonAndCancelButton {
    CGFloat height = 40;
    UIButton *cancelBtn = [self buttonWithFrame:CGRectMake(0, self.cw_height - height, self.cw_width / 2.0, height) title:@"放弃并返回" titleColor:MAIN_BLUE_COLOR font:[UIFont systemFontOfSize:18] backImageNor:@"aio_record_cancel_button" backImageHighled:@"aio_record_cancel_button_press" sel:@selector(btnClick:)];
    [self addSubview:cancelBtn];
    self.cancelButton = cancelBtn;
    
    UIButton *sendBtn = [self buttonWithFrame:CGRectMake(self.cw_width / 2.0, self.cw_height - height, self.cw_width / 2.0, height) title:@"马上发送" titleColor:MAIN_BLUE_COLOR font:[UIFont systemFontOfSize:18] backImageNor:@"aio_record_send_button" backImageHighled:@"aio_record_send_button_press" sel:@selector(btnClick:)];
    [self addSubview:sendBtn];
    self.sendButton = sendBtn;
    
}

- (UIButton *)buttonWithFrame:(CGRect)frame title:(NSString *)title titleColor:(UIColor *)titleColor font:(UIFont *)font backImageNor:(NSString *)backImageNor backImageHighled:(NSString *)backImageHighled sel:(SEL)sel{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:titleColor forState:UIControlStateNormal];
    btn.titleLabel.font = font;
    UIImage *newImageNor = [[UIImage imageNamed:backImageNor] stretchableImageWithLeftCapWidth:2 topCapHeight:2];
    UIImage *newImageHighled = [[UIImage imageNamed:backImageHighled] stretchableImageWithLeftCapWidth:2 topCapHeight:2];
    [btn setBackgroundImage:newImageNor forState:UIControlStateNormal];
    [btn setBackgroundImage:newImageHighled forState:UIControlStateHighlighted];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

#pragma mark - playTimer
- (void)startPlayTimer {
//    _allCount = self.allLevels.count;
    [self.playTimer invalidate];
    self.playTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updatePlayMeter)];
    
    if ([[UIDevice currentDevice].systemVersion floatValue] > 10.0) {
        self.playTimer.preferredFramesPerSecond = 10;
    }else {
        self.playTimer.frameInterval = 6;
    }
    [self.playTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)updatePlayMeter {
    [self.playingView updateLevels];
}

- (void)stopPlay {
    [[CWAudioPlayer shareInstance] stopCurrentAudio];
}

- (void)btnClick:(UIButton *)btn {
    //    NSLog(@"%@",btn.titleLabel.text);
    
    [self stopPlay];
    if (btn == self.sendButton) { // 发送
        // wav to aac
        NSString* pathtem = self.playingView.voicePath;
        if ([pathtem length] <= 0) {
            pathtem = [CWRecordModel shareInstance].path;
        }
        NSString* tpath = [NSString stringWithFormat:@"%@.m4a", pathtem];
        self.audioconverter = [[QLTPAACAudioConverter alloc]initWithDelegate:self source:pathtem destination:tpath];
        [self.audioconverter start];
        [QMUITips showLoading:@"紧急发送中，请稍安勿躁" inView:[QLglobalvar shareglobalvar].mizhiyinvc.view];
    }else {
        NSLog(@"取消并返回");
        [[CWRecorder shareInstance] deleteRecord]; // 会删除录音文件
        [CWFlieManager removeFile:self.playingView.voicePath];
        
        [(QLCWVoiceView *)self.superview.superview.superview setState:CWVoiceStateDefault];
        [UIView transitionWithView:self duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self removeFromSuperview];
        } completion:nil];
    }
}

// 发送出口一：成功转成aac，并发送完毕（成功或失败）
- (BOOL)request_sendaudio {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"application/json"];
    manager.requestSerializer=[AFJSONRequestSerializer serializer];
    NSString* requesturl = [zyprotocol_sendaudio sendaudio_url];
    NSString* pathtem = self.playingView.voicePath;
    if ([pathtem length] <= 0) {
        pathtem = [CWRecordModel shareInstance].path;
    }
    NSString* tpath = [NSString stringWithFormat:@"%@.m4a", pathtem];
    NSData* audiodata = [NSData dataWithContentsOfFile:tpath];
    NSDictionary* param = [zyprotocol_sendaudio sendaudio_parame:audiodata audiolen:[CWRecordModel shareInstance].duration towhere:[QLglobalvar shareglobalvar].towhere+1 otherid:[QLglobalvar shareglobalvar].toclientid];
    NSError *error = nil;
    NSDictionary *result = [manager syncPOST:requesturl
                                  parameters:param
                                        task:NULL
                                       error:&error];
    protocol_sendaudio_info* sendaudioinfo = [zyprotocol_sendaudio token_response:result];
    BOOL ret = NO;
    if (sendaudioinfo.IsSuccess) {
        NSLog(@"request sendaudio successful");
        dispatch_sync(dispatch_get_main_queue(), ^{
            [QMUITips hideAllTipsInView:[QLglobalvar shareglobalvar].mizhiyinvc.view];
            NSString* tips = @"已经发送到\"天涯何处\"，可到\"寡人\"处查看发送记录";
            if ([QLglobalvar shareglobalvar].towhere == 1) {
                tips = [NSString stringWithFormat:@"已经发给\"%@\"，可到\"寡人\"处查看发送记录", [QLglobalvar shareglobalvar].tonickname];
            }
            [QMUITips showSucceed:tips inView:[QLglobalvar shareglobalvar].mizhiyinvc.view hideAfterDelay:3];
            
            [(QLCWVoiceView *)self.superview.superview.superview setState:CWVoiceStateDefault];
            [UIView transitionWithView:self duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                [self removeFromSuperview];
            } completion:nil];
            
        });
        ret = YES;
    }
    else {
        NSLog(@"request sendaudio error");
        dispatch_sync(dispatch_get_main_queue(), ^{
            [QMUITips hideAllTipsInView:[QLglobalvar shareglobalvar].mizhiyinvc.view];
            [QMUITips showError:@"发送遇阻，请确保网络畅通，再来一次吧。" inView:[QLglobalvar shareglobalvar].mizhiyinvc.view hideAfterDelay:3];
            
            [(QLCWVoiceView *)self.superview.superview.superview setState:CWVoiceStateDefault];
            [UIView transitionWithView:self duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                [self removeFromSuperview];
            } completion:nil];
        });
    }
    
    [CWFlieManager removeFile:tpath];
    [CWFlieManager removeFile:[CWRecordModel shareInstance].path];
    [CWFlieManager removeFile:self.playingView.voicePath];
    
    return ret;
}

-(void)sendRecordfile {
    NSLog(@"send record, path:%@", self.playingView.voicePath);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self request_sendaudio];
    });
}

-(void)AACAudioConverter:(QLTPAACAudioConverter *)converter didMakeProgress:(float)progress {
    NSLog(@"convert progress: %f", progress);
}

-(void)AACAudioConverterDidFinishConversion:(QLTPAACAudioConverter *)converter {
    NSLog(@"convert finish");
    [self sendRecordfile];
}

// 发送出口二：转aac失败（不发送）
-(void)AACAudioConverter:(QLTPAACAudioConverter *)converter didFailWithError:(NSError *)error {
    NSLog(@"convert fail, %@", [error localizedDescription]);
    [QMUITips hideAllTipsInView:[QLglobalvar shareglobalvar].mizhiyinvc.view];
    [QMUITips showError:@"压缩数据时遇挫，再来一次吧（或在\"寡人\"处投诉作者！）" inView:[QLglobalvar shareglobalvar].mizhiyinvc.view hideAfterDelay:3];
    
    NSString* tpath = [NSString stringWithFormat:@"%@.m4a", self.playingView.voicePath];
    [CWFlieManager removeFile:tpath];
    [CWFlieManager removeFile:[CWRecordModel shareInstance].path];
    [CWFlieManager removeFile:self.playingView.voicePath];
    [(QLCWVoiceView *)self.superview.superview.superview setState:CWVoiceStateDefault];
    [self removeFromSuperview];
}


@end
