//
//  MainViewController.m
//  WebViewDemo
//
//  Created by Fater on 2019/9/4.
//  Copyright © 2019 PslP. All rights reserved.
//

#import "MainViewController.h"
#import "UIViewAdditions.h"
#import <WebKit/WebKit.h>

//该类负责解决WKWebView内存问题
@interface WebViewMessageHandlerHelper : NSObject<WKScriptMessageHandler>

@property (nonatomic, weak) id<WKScriptMessageHandler> scriptDelegate;

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;

@end

@implementation WebViewMessageHandlerHelper

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate {
    if (self = [super init]) {
        _scriptDelegate = scriptDelegate;
    }

    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([self.scriptDelegate respondsToSelector:@selector(userContentController:didReceiveScriptMessage:)]) {
        [self.scriptDelegate userContentController:userContentController didReceiveScriptMessage:message];
    }
}

@end

#pragma MainViewController

static int* const kWebViewProgress;
static int* const kWebViewTitle;

@interface MainViewController ()<WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *mWebView;
@property (nonatomic, strong) UIProgressView *mProgressView;

@end

@implementation MainViewController

- (void)dealloc {
    [self.mWebView removeObserver:self forKeyPath:@"estimateProgress" context:kWebViewProgress];
    [self.mWebView removeObserver:self forKeyPath:@"title" context:kWebViewTitle];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initView];
    [self initNavigationItem];
    [self initKVOForWebView];
}

#pragma action

- (void)goBackAction:(id)sender {
    [self.mWebView goBack];
}

- (void)refreshAction:(id)sender {
    [self.mWebView reload];
}

- (void)localHtmlClicked {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"FF.html" ofType:nil];
    NSString *htmlString = [[NSString alloc]initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    [self.mWebView loadHTMLString:htmlString baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
}

// webview调用js方法
- (void)ocToJs {
    NSString *jsString = [NSString stringWithFormat:@"changeColor()"];
    [self.mWebView evaluateJavaScript:jsString completionHandler:^(id _Nullable data, NSError * _Nullable error) {
        NSLog(@"改变HTML的背景色");
    }];

    //改变字体大小 调用原生JS方法
    NSString *jsFont = [NSString stringWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%d%%'", arc4random()%99 + 100];
    [self.mWebView evaluateJavaScript:jsFont completionHandler:nil];
}

#pragma WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSLog(@"name:%@\\\\n body:%@\\\\n frameInfo:%@\\\\n",message.name,message.body,message.frameInfo);
    //用message.body获得JS传出的参数体
    NSDictionary *parameter = message.body;
    //JS调用OC
    if ([message.name isEqualToString:@"jsToOcNoPrams"]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"js调用到了oc" message:@"不带参数" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:([UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {}])];
        [self presentViewController:alertController animated:YES completion:nil];

    } else if ([message.name isEqualToString:@"jsToOcWithPrams"]){
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"js调用到了oc" message:parameter[@"params"] preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:([UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }])];
        [self presentViewController:alertController animated:YES completion:nil];
    }

}

#pragma WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"HTML的弹出框"
                                        message:message?:@""
                                 preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}

//confirm(message)
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Confirm" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }];
    [alertController addAction:cancelAction];
    [alertController addAction:confirmAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma init

- (void)initKVOForWebView {
    [self.mWebView addObserver:self
                    forKeyPath:@"estimateProgress"
                       options:NSKeyValueObservingOptionNew
                       context:kWebViewProgress];

    [self.mWebView addObserver:self
                    forKeyPath:@"title"
                       options:NSKeyValueObservingOptionNew
                       context:kWebViewTitle];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {

    if (context == kWebViewProgress) {
        self.mProgressView.progress = self.mWebView.estimatedProgress;
    } else if (context == kWebViewTitle) {
        self.navigationItem.title = self.mWebView.title;
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (void)initNavigationItem {
    // 后退按钮
    UIButton *goBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [goBackButton setImage:[UIImage imageNamed:@"backButton"] forState:UIControlStateNormal];
    [goBackButton addTarget:self action:@selector(goBackAction:) forControlEvents:UIControlEventTouchUpInside];
    goBackButton.frame = CGRectMake(0, 0, 30, 30);
    UIBarButtonItem *goBackButtonItem = [[UIBarButtonItem alloc] initWithCustomView:goBackButton];

    UIBarButtonItem *jstoOc = [[UIBarButtonItem alloc] initWithTitle:@"首页" style:UIBarButtonItemStyleDone target:self action:@selector(localHtmlClicked)];
    self.navigationItem.leftBarButtonItems = @[goBackButtonItem,jstoOc];

    // 刷新按钮
    UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [refreshButton setImage:[UIImage imageNamed:@"webRefreshButton"] forState:UIControlStateNormal];
    [refreshButton addTarget:self action:@selector(refreshAction:) forControlEvents:UIControlEventTouchUpInside];
    refreshButton.frame = CGRectMake(0, 0, 30, 30);
    UIBarButtonItem *refreshButtonItem = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];

    UIBarButtonItem * ocToJs = [[UIBarButtonItem alloc] initWithTitle:@"OC调用JS" style:UIBarButtonItemStyleDone target:self action:@selector(ocToJs)];
    self.navigationItem.rightBarButtonItems = @[refreshButtonItem, ocToJs];
}

- (void)initView {
    self.view.backgroundColor = [UIColor whiteColor];

    self.mProgressView.top = self.view.top + 1;
    self.mProgressView.left = self.view.left;
    self.mProgressView.width = self.view.width;
    self.mProgressView.height = 2;
    [self.view addSubview:self.mProgressView];

    self.mWebView.top = self.view.top + self.mProgressView.bottom;
    self.mWebView.left = self.view.left;
    self.mWebView.width = self.view.width;
    self.mWebView.height = 800;
    [self.view addSubview:self.mWebView];
}

#pragma getter

- (WKWebView *)mWebView {
    if (!_mWebView) {
        WKPreferences *mPreference = [WKPreferences new];
        mPreference.minimumFontSize = 0;
        mPreference.javaScriptEnabled = YES;
        mPreference.javaScriptCanOpenWindowsAutomatically = YES;

        WebViewMessageHandlerHelper *messageHelper = [[WebViewMessageHandlerHelper alloc] initWithDelegate:self];
        WKUserContentController *wkUController = [[WKUserContentController alloc] init];
        [wkUController addScriptMessageHandler:messageHelper name:@"jsToOcNoPrams"];
        [wkUController addScriptMessageHandler:messageHelper name:@"jsToOcWithPrams"];

        //以下代码适配文本大小
        NSString *jSString = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
        //用于进行JavaScript注入
        WKUserScript *wkUScript = [[WKUserScript alloc] initWithSource:jSString injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [wkUController addUserScript:wkUScript];


        WKWebViewConfiguration *mConfig = [WKWebViewConfiguration new];
        mConfig.preferences = mPreference;
        mConfig.userContentController = wkUController;
        mConfig.allowsAirPlayForMediaPlayback = YES;
        mConfig.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
        mConfig.allowsPictureInPictureMediaPlayback = YES;

        _mWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:mConfig];
        _mWebView.UIDelegate = self;
        _mWebView.navigationDelegate = self;
        _mWebView.allowsBackForwardNavigationGestures = YES;

        NSString *path = [[NSBundle mainBundle] pathForResource:@"FF.html" ofType:nil];
        NSString *htmlString = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        [_mWebView loadHTMLString:htmlString baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
    }

    return _mWebView;
}

- (UIProgressView *)mProgressView {
    if (!_mProgressView) {
        _mProgressView = [[UIProgressView alloc] init];
        _mProgressView.tintColor = [UIColor blueColor];
        _mProgressView.trackTintColor = [UIColor clearColor];
    }

    return _mProgressView;
}

@end
