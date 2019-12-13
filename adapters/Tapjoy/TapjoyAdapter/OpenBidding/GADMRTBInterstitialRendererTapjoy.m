// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GADMRTBInterstitialRendererTapjoy.h"

#import <Tapjoy/Tapjoy.h>

#import "GADMAdapterTapjoy.h"
#import "GADMAdapterTapjoyConstants.h"
#import "GADMAdapterTapjoySingleton.h"
#import "GADMTapjoyExtras.h"
#import "GADMediationAdapterTapjoy.h"

@interface GADMRTBInterstitialRendererTapjoy () <GADMediationInterstitialAd,
                                                 TJPlacementDelegate,
                                                 TJPlacementVideoDelegate>

@property(nonatomic, strong) GADMediationInterstitialAdConfiguration *adConfig;

@property(nonatomic, copy) GADMediationInterstitialLoadCompletionHandler renderCompletionHandler;

@property(nonatomic, strong) TJPlacement *interstitialAd;

@property(nonatomic, weak) id<GADMediationInterstitialAdEventDelegate> delegate;

@property(nonatomic, copy) NSString *placementName;

@end

@implementation GADMRTBInterstitialRendererTapjoy

/// Asks the receiver to render the ad configuration.
- (void)renderInterstitialForAdConfig:(nonnull GADMediationInterstitialAdConfiguration *)adConfig
                    completionHandler:
                        (nonnull GADMediationInterstitialLoadCompletionHandler)handler {
  _renderCompletionHandler = handler;
  _adConfig = adConfig;
  _placementName = adConfig.credentials.settings[kGADMAdapterTapjoyPlacementKey];
  NSString *sdkKey = adConfig.credentials.settings[kGADMAdapterTapjoySdkKey];

  if (!sdkKey.length || !_placementName.length) {
    NSError *adapterError = [NSError
        errorWithDomain:kGADMAdapterTapjoyErrorDomain
                   code:0
               userInfo:@{
                 NSLocalizedDescriptionKey : @"Did not receive valid Tapjoy server parameters"
               }];
    handler(nil, adapterError);
    return;
  }

  GADMTapjoyExtras *extras = adConfig.extras;
  GADMAdapterTapjoySingleton *sharedInstance = [GADMAdapterTapjoySingleton sharedInstance];

  if (Tapjoy.isConnected) {
    [self requestInterstitialAd];
  } else {
    NSDictionary *connectOptions =
        @{TJC_OPTION_ENABLE_LOGGING : [NSNumber numberWithInt:extras.debugEnabled]};
    GADMRTBInterstitialRendererTapjoy *__weak weakSelf = self;
    [sharedInstance initializeTapjoySDKWithSDKKey:sdkKey
                                          options:connectOptions
                                completionHandler:^(NSError *error) {
                                  GADMRTBInterstitialRendererTapjoy *__strong strongSelf = weakSelf;
                                  if (error) {
                                    handler(nil, error);
                                  } else if (strongSelf) {
                                    [strongSelf requestInterstitialAd];
                                  }
                                }];
  }
}

- (void)requestInterstitialAd {
  GADMTapjoyExtras *extras = _adConfig.extras;
  [Tapjoy setDebugEnabled:extras.debugEnabled];
  _interstitialAd =
      [[GADMAdapterTapjoySingleton sharedInstance] requestAdForPlacementName:_placementName
                                                                 bidResponse:_adConfig.bidResponse
                                                                    delegate:self];
}

#pragma mark GADMediationInterstitialAd

- (void)presentFromViewController:(nonnull UIViewController *)viewController {
  if ([_interstitialAd isContentAvailable])
    [_interstitialAd showContentWithViewController:viewController];
}

#pragma mark TajoyPlacementDelegate methods
- (void)requestDidSucceed:(nonnull TJPlacement *)placement {
  if (!placement.isContentAvailable) {
    NSError *adapterError = [NSError errorWithDomain:kGADMAdapterTapjoyErrorDomain
                                                code:0
                                            userInfo:@{NSLocalizedDescriptionKey : @"NO_FILL"}];
    self.renderCompletionHandler(nil, adapterError);
  }
}

- (void)requestDidFail:(nonnull TJPlacement *)placement error:(nonnull NSError *)error {
  self.renderCompletionHandler(nil, error);
}

- (void)contentIsReady:(nonnull TJPlacement *)placement {
  self.delegate = self.renderCompletionHandler(self, nil);
}

- (void)contentDidAppear:(nonnull TJPlacement *)placement {
  id<GADMediationInterstitialAdEventDelegate> strongDelegate = self.delegate;
  [strongDelegate willPresentFullScreenView];
  [strongDelegate reportImpression];
}

- (void)contentDidDisappear:(nonnull TJPlacement *)placement {
  id<GADMediationInterstitialAdEventDelegate> strongDelegate = self.delegate;
  [strongDelegate willDismissFullScreenView];
  [strongDelegate didDismissFullScreenView];
}

@end
