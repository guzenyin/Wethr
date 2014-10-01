//
//  ForecastView.m
//  Forecast
//
//  Created by Mike on 10/1/14.
//  Copyright (c) 2014 Mike Amaral. All rights reserved.
//

#import "WethrView.h"

typedef void (^currentWeatherHandler)(NSDictionary *weatherData);
typedef void (^locationHandler)(CLLocation *currentLocation);

@implementation WethrView {
    CLLocationManager *_locationManager;
    locationHandler _locationHandler;
    BOOL _debugLoggingEnabled;
}

static NSString * const kDefaultFontName = @"HelveticaNeue-UltraLight";

static CGFloat const kTempLabelMultiplier = 0.5;
static CGFloat const kConditionsLabelMultiplier = 0.3;
static CGFloat const kCityLabelMultiplier = 0.2;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    self.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.5];
    
    _locationManager = [CLLocationManager new];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    CGFloat width = CGRectGetWidth(frame);
    CGFloat height = CGRectGetHeight(frame);
    CGFloat tempLabelHeight = height * kTempLabelMultiplier;
    CGFloat conditionsLabelHeight = height * kConditionsLabelMultiplier;
    CGFloat cityLabelHeight = height * kCityLabelMultiplier;
    
    self.tempLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, tempLabelHeight)];
    self.tempLabel.textAlignment = NSTextAlignmentCenter;
    self.tempLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight;
    self.tempLabel.textColor = [UIColor whiteColor];
    self.tempLabel.font = [UIFont fontWithName:kDefaultFontName size:tempLabelHeight];
    self.tempLabel.adjustsFontSizeToFitWidth = YES;
    self.tempLabel.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
    [self addSubview:self.tempLabel];
    
    self.conditionsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.tempLabel.frame), width, conditionsLabelHeight)];
    self.conditionsLabel.textAlignment = NSTextAlignmentCenter;
    self.conditionsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight;
    self.conditionsLabel.textColor = [UIColor whiteColor];
    self.conditionsLabel.font = [UIFont fontWithName:kDefaultFontName size:conditionsLabelHeight];
    self.conditionsLabel.adjustsFontSizeToFitWidth = YES;
    self.conditionsLabel.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.5];
    [self addSubview:self.conditionsLabel];
    
    self.cityLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.conditionsLabel.frame), width, cityLabelHeight)];
    self.cityLabel.textAlignment = NSTextAlignmentCenter;
    self.cityLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight;
    self.cityLabel.textColor = [UIColor whiteColor];
    self.cityLabel.font = [UIFont fontWithName:kDefaultFontName size:cityLabelHeight];
    self.cityLabel.adjustsFontSizeToFitWidth = YES;
    self.cityLabel.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.5];
    [self addSubview:self.cityLabel];
    
    _debugLoggingEnabled = NO;
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    
    UIActivityIndicatorView *progressView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    progressView.frame = self.bounds;
    progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [progressView startAnimating];
    [self addSubview:progressView];
    
    [self getCurrentWeatherDataWithCompletionHandler:^(NSDictionary *weatherData) {
        [progressView stopAnimating];
        [progressView removeFromSuperview];
        
        [self updateWeatherData:weatherData];
    }];
}

- (void)updateWeatherData:(NSDictionary *)weatherData {
    self.cityLabel.text = weatherData[@"name"];
    
    NSDictionary *weatherDict = [weatherData[@"weather"] firstObject];;
    self.conditionsLabel.text = weatherDict[@"main"];
    
    NSDictionary *mainDict = weatherData[@"main"];
    NSNumber *kelvinTemp = mainDict[@"temp"];
    NSNumber *fahrenheitTemp = [self fahrenheitFromKelvin:kelvinTemp];
    self.tempLabel.text = [NSString stringWithFormat:@"%@°", fahrenheitTemp];
}


#pragma mark - Location Manager Delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    _locationHandler(locations.lastObject);
    [_locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [self log:@"Location manager failed with error: %@", error.localizedDescription];
}


#pragma mark - Weather API

- (void)getCurrentWeatherDataWithCompletionHandler:(currentWeatherHandler)handler {
    [self getCurrentLocationWithCompletionHandler:^(CLLocation *currentLocation) {
        NSNumber *lat = @(currentLocation.coordinate.latitude);
        NSNumber *lon = @(currentLocation.coordinate.longitude);
        NSString *URL = @"http://api.openweathermap.org/data/2.5/weather";
        NSDictionary *params = @{@"lat": lat, @"lon": lon};
        
        [self sendRequestToURL:URL method:@"GET" withBody:params successHandler:^(NSDictionary *resultDictionary) {
            handler(resultDictionary);
        } errorHandler:^(NSDictionary *resultDictionary, NSError *error) {
            // TODO: Determine what we want to do if the request fails...
        }];
    }];
}

- (void)sendRequestToURL:(NSString *)URL method:(NSString *)method withBody:(NSDictionary *)body successHandler:(void (^)(NSDictionary *resultDictionary))successHandler errorHandler:(void (^)(NSDictionary *resultDictionary, NSError *error))errorHandler {
    // dispatch this block of code on a separate thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSData *data;
        NSString *requestURL = URL;
        BOOL isGET = [method isEqualToString:@"GET"];
        
        // if this is NOT a GET request and we were given a dictionary for the body of the request, serialize
        // the dictionary to JSON and if the serialized data is nil, an error occurred, so pass the error back
        // in the handler and bail
        if (!isGET && body) {
            NSError *serializationError;
            data = [NSJSONSerialization dataWithJSONObject:body options:0 error:&serializationError];
            
            if (!data) {
                [self log:@"A serialization error occurred: %@", serializationError];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    errorHandler(nil, serializationError);
                });
                return;
            }
            
            [self log:@"Sending %@ request to URL: %@ with body: %@", method, requestURL, body];
        }
        
        // otherwise if the request is a GET request and we have params, we want to
        // add them to the URL
        else if (isGET && body) {
            requestURL = [self createFullURLStringFromBaseURL:URL params:body];
            [self log:@"Sending %@ request to URL: %@", method, requestURL];
        }
        
        // otherwise we have no parameters for the request and the URL is unchanged
        else {
            [self log:@"Sending %@ request to URL: %@", method, requestURL];
        }
        
        // create our URL request and send a synchronous request (we're already on a background thread) and load the data we received
        NSMutableURLRequest *request = [self createURLRequestWithURLString:requestURL method:method data:data];
        NSError *requestError;
        NSHTTPURLResponse *response;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
        
        // if we don't have response data, call the error handler with the error back on the main thread and bail
        if (!responseData) {
            [self log:@"We got no response back from the server. Error: %@", requestError];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                errorHandler(nil, requestError);
            });
            return;
        }
        
        // deserialize the JSON into a dictionary
        NSError *deserializationError;
        NSDictionary *resultDictionary = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&deserializationError];
        
        // if there was an issue deserializing the JSON, log and return it
        if (!resultDictionary) {
            [self log:@"Error parsing JSON into dictionary: %@", deserializationError];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                errorHandler(nil, deserializationError);
            });
            return;
        }
        
        // if we got back a 200 response
        else if (response.statusCode == 200) {
            [self log:@"Got 200 response code with result: %@", resultDictionary];
            
            // and send back the data on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                successHandler(resultDictionary);
            });
        }
        
        // otherwise we don't currently do anything specifically related to a particular response/error code
        // so if we got any other status code back return the error
        else {
            [self log:@"Got %@ response code with result: %@", @(response.statusCode), resultDictionary];
            
            // create the error with the response code
            NSError *responseError = [NSError errorWithDomain:@"ping4alertsManager" code:response.statusCode userInfo:nil];
            
            // pass it back on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                errorHandler(resultDictionary, responseError);
            });
            
            return;
        }
    });
}

- (NSString *)createFullURLStringFromBaseURL:(NSString *)URL params:(NSDictionary *)params {
    // if the params dictionary is nil or empty return the base URL unchanged
    if (!params || params.count == 0) {
        return URL;
    }
    
    // we want to split up the parameters by key/value and appropriately format the URL with it,
    // so we are going to loop through all of the keys, get the corresponding object for the key, url-encode both
    // the key and value and concatenate them appropriately and add them to the params array, which we will then
    // join all the components with & to be added to the url
    NSMutableArray *paramsArray = [NSMutableArray array];
    
    for (NSString *key in [params allKeys]) {
        [paramsArray addObject:[NSString stringWithFormat:@"%@=%@", [self urlEncode:key], [self urlEncode:[NSString stringWithFormat:@"%@", params[key]]]]];
    }
    
    NSString *paramsString = [paramsArray componentsJoinedByString:@"&"];
    return [URL stringByAppendingFormat:@"?%@", paramsString];
}

- (NSString *)urlEncode:(NSString *)str {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)str, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8));
}

- (NSMutableURLRequest *)createURLRequestWithURLString:(NSString *)urlString method:(NSString *)method data:(NSData *)data {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:method];
    [request setValue:[NSString stringWithFormat:@"%@", @([data length])] forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:method forHTTPHeaderField:@"Request-Method"];
    [request setHTTPBody:data];
    return request;
}

- (void)getCurrentLocationWithCompletionHandler:(locationHandler)handler {
    _locationHandler = handler;
    
    if ([_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [_locationManager requestWhenInUseAuthorization];
    }
    
    [_locationManager startUpdatingLocation];
}


#pragma mark - Utilities

- (NSNumber *)fahrenheitFromKelvin:(NSNumber *)kelvin {
    double kelvinValue = [kelvin doubleValue];
    NSInteger convertedValue =  ceil((kelvinValue - 273.15) * 1.8000 + 32.00);
    return @(convertedValue);
}


#pragma mark - Logging

- (void)log:(NSString *)format, ... {
    // All this method does is log information as long as debug logging is enabled.
    if (!_debugLoggingEnabled || !format) {
        return;
    }
    
    va_list args, args_copy;
    va_start(args, format);
    va_copy(args_copy, args);
    va_end(args);
    
    NSString *logText = [[NSString alloc] initWithFormat:format arguments:args_copy];
    NSLog(@"%@", logText);
    
    va_end(args_copy);
}

@end