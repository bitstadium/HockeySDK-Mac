//
//  BITHockeyBaseManager.h
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 The internal superclass for all component managers
 
 */

@interface BITHockeyBaseManager : NSObject {
@private
  NSDateFormatter *_rfc3339Formatter;
  
  NSString *_appIdentifier;
  
  NSString *_userID;
  NSString *_userName;
  NSString *_userEmail;
  
  NSString *_serverURL;
}

///-----------------------------------------------------------------------------
/// @name Modules
///-----------------------------------------------------------------------------


/**
 Defines the server URL to send data to or request data from
 
 By default this is set to the HockeyApp servers and there rarely should be a
 need to modify that.
 */
@property (nonatomic, strong) NSString *serverURL;


@end
