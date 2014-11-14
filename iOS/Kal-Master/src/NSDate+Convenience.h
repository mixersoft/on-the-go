//
//  NSDate+Convenience.h
//  FiveStar
//
//  Created by Leon on 13-1-14.
//
//

#import <Foundation/Foundation.h>

@interface NSDate (Convenience)

- (NSInteger)year;
- (NSInteger)month;
- (NSInteger)day;
- (NSInteger)hour;
- (NSString *)weekString;
- (NSDate *)offsetDay:(NSInteger)numDays;
- (BOOL)isToday;

+ (NSDate *)dateForDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year;
+ (NSDate *)dateStartOfDay:(NSDate *)date;
+ (NSInteger)dayBetweenStartDate:(NSDate *)startDate endDate:(NSDate *)endDate;
+ (NSDate *)dateFromString:(NSString *)dateString format:(NSString *)format;
+ (NSString *)stringFromDate:(NSDate *)date format:(NSString *)format;
+ (NSDate *)dateFromString:(NSString *)dateString;
+ (NSDate *)dateFromStringBySpecifyTime:(NSString *)dateString hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second;
+ (NSDateComponents *)nowDateComponents;
+ (NSDateComponents *)dateComponentsFromNow:(NSInteger)days;

@end
