//
//  AbsoluteTouchHandler.h
//  Moonlight
//
//  Created by TimmyOVO on 3/4/24.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#import "StreamView.h"

NS_ASSUME_NONNULL_BEGIN

@interface PassthroughTouchHandler : UIResponder

-(id)initWithView:(StreamView*)view;

@end

NS_ASSUME_NONNULL_END
