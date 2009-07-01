#import "NSLogView.h"
#import "LogWindow.h"
#import "GTLog.h"
#import "LogTextField.h"
#import "defines.h"

#define MoveDragType 2
#define ResizeDragType 1

// this class exists so we can move/resize our borderless window unfortunately, these common functions are unavailable to us because we are using an NSBorderlessWindow, so we must recreate them manually ourselves
@implementation NSLogView

- (void)awakeFromNib
{
    [self setNextResponder: [NSApplication sharedApplication]];
}

#pragma mark View Attributes
    // lets us so user can move window immediately, instead of clicking on it to make it "active" and then again to actually move it
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

// dont push logs up to the top
- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
    if ([theEvent type] == NSLeftMouseDragged) return NO;
    else return YES;
}

- (BOOL)acceptsFirstResponder
{
    if (highlighted)
        return YES;
    return NO;
}

- (BOOL)resignFirstResponder
{
    if (highlighted)
        return YES;
    return NO;
}

- (BOOL)becomeFirstResponder
{
    if (highlighted)
        return YES;
    return NO;
}

#pragma mark Mouse Handling
- (void)mouseDown:(NSEvent *)theEvent
{
    NSWindow *window = [self window];
    
    // dont accept clicks if the view is not highlighted
    if (!highlighted)
        return;
    
    mouseLoc = [window convertBaseToScreen:[theEvent locationInWindow]];
    windowFrame = [window frame];
    
    // figure out where we are clicking either on the resize handle or not
    if (NSMouseInRect(mouseLoc,NSMakeRect(NSMaxX(windowFrame) - 10,NSMaxY(windowFrame) - NSHeight(windowFrame),10,10),NO))
        dragType = ResizeDragType;
    else
        dragType = MoveDragType;
    
    /*
    if ([(LogWindowController*)logWindowController type] == TYPE_SHELL)
        [(LogWindowController*)logWindowController scrollEnd];
    [self display];
     */
    
    [[(LogWindow*)[logWindowController window]parentLog]setIsBeingDragged:TRUE];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSWindow *window = [self window];
    NSRect newWindowFrame = windowFrame;
    
    // check to see if we are resizing
    if (dragType == ResizeDragType)
    {                
        // Get the mouse location in window coordinates.    
        NSPoint currentMouseLoc = [NSEvent mouseLocation];
        
        NSPoint delta = NSMakePoint(currentMouseLoc.x - mouseLoc.x,currentMouseLoc.y - mouseLoc.y);
        
        newWindowFrame.size.width += delta.x;
        newWindowFrame.size.height -= delta.y;
        newWindowFrame.origin.y += delta.y;
        //X coord does not change
        //windowFrame.origin.x;
        
        /*
         // don't let the window be resized smaller than 20x20
         if (windowFrame.size.width < 20)
         windowFrame.size.width = 20;
         
         if (windowFrame.size.height < 20)
         windowFrame.size.height = 20;
         */
        /*
         // snap to edges of window
         if ([(GeekTool*)[NSApplication sharedApplication] magn])
         {
         NSEnumerator *e = [[(GeekTool*)[NSApplication sharedApplication] xGuides] objectEnumerator];
         NSEnumerator *f = [[(GeekTool*)[NSApplication sharedApplication] yGuides] objectEnumerator];
         NSNumber *xn, *yn;
         
         while (xn = [e nextObject])
         {
         float x = [xn floatValue];
         if ((x - MAGN <= newX + newW) && (newX + newW <= x + MAGN))
         newW = x - newX;
         }
         while (yn = [f nextObject])
         {
         float y = [yn  floatValue];
         if ((y - MAGN <= newY) && (newY <= y + MAGN))
         {
         newH = newH + ( newY - y);
         newY = y;
         }
         }
         }
         */
        
        [window setFrame:newWindowFrame display:YES animate:NO];
        [[NSNotificationCenter defaultCenter]postNotificationName:NSWindowDidResizeNotification object:window];
    }
    // we are moving the window, not resizing it
    else
    {
        NSPoint newOrigin = windowFrame.origin;
        NSPoint currentMouseLoc = [NSEvent mouseLocation];

        // Update the origin with the difference between the new mouse location and the old mouse location.
        newOrigin.x += (currentMouseLoc.x - mouseLoc.x);
        newOrigin.y += currentMouseLoc.y - mouseLoc.y;
        
        newWindowFrame.origin = newOrigin;
        
        /*
         // snap to edges of screen if close enough
         if ([(GeekTool*)[NSApplication sharedApplication] magn])
         {
         NSEnumerator *e = [[(GeekTool*)[NSApplication sharedApplication] xGuides] objectEnumerator];
         NSEnumerator *f = [[(GeekTool*)[NSApplication sharedApplication] yGuides] objectEnumerator];
         NSNumber *xn, *yn;
         
         while (xn = [e nextObject])
         {
         float x = [xn floatValue];
         if (x - MAGN <= newX && newX <= x + MAGN)
         newX = x;
         if (x - MAGN <= newX + newW && newX + newW <= x + MAGN)
         newX = x - newW;
         }
         while (yn = [f nextObject])
         {
         float y = [yn  floatValue];
         if (y - MAGN <= newY && newY <= y + MAGN)
         newY = y;
         if (y - MAGN <= newY + newH && newY + newH <= y + MAGN)
         newY = y - newH;
         }
         }
         */
        
        // Move the window to the new location
        [[NSNotificationCenter defaultCenter]postNotificationName:NSWindowWillMoveNotification object:window];
        [window setFrameOrigin:newWindowFrame.origin];
        [[NSNotificationCenter defaultCenter]postNotificationName:NSWindowDidMoveNotification object:window];		
    }
    
    [[(LogWindow*)[logWindowController window]parentLog] setCoords:[self convertToNTCoords:[[self window] frame]]];
}

- (void)mouseUp:(NSEvent *)theEvent;
{
    if ([[[(LogWindow*)[logWindowController window]parentLog]properties]valueForKey:@"type"] == TYPE_SHELL)
        [[(LogWindow*)[logWindowController window]textView]scrollEnd];
    [text display];
    

    [[(LogWindow*)[logWindowController window]parentLog]setIsBeingDragged:FALSE];
}

#pragma mark View Drawing
- (void)drawRect:(NSRect)rect
{
    [super drawRect: rect];
    NSBezierPath *bp = [NSBezierPath bezierPathWithRect:[self bounds]];
    NSColor *color;
    
    // if we want this window to be highlighted
    if (highlighted)
    {
        color = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"selectionColor"]];
        
        // further drawing will be done with this color
        [color set];
        
        // fill rect with this color
        [bp fill];
        
        [corner setImage:[NSImage imageNamed:@"coin"]];
    }
    else
    {
        // make the background clear
        color = [NSColor clearColor];
        [color set];
        [bp fill];
        
        // get rid of the corner handler, since we won't be needing it
        [corner setImage: nil];
    }
}

#pragma mark Misc Actions
- (void)setHighlighted:(BOOL)flag
{
    highlighted = flag;
    if (highlighted)
        [[self window] makeKeyWindow];
    [self setNeedsDisplay:YES];
}

- (NSRect)convertToNTCoords:(NSRect)appleCoordRect
{
    NSRect screenSize = [[NSScreen mainScreen] frame];
    return NSMakeRect(appleCoordRect.origin.x,(screenSize.size.height - appleCoordRect.origin.y - appleCoordRect.size.height),appleCoordRect.size.width,appleCoordRect.size.height);
}

@end
