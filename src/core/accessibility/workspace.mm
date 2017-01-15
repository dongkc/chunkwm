#import <Cocoa/Cocoa.h>
#import "workspace.h"
#include "event.h"

#define internal static
@interface WorkspaceWatcher : NSObject {
}
- (id)init;
@end

internal WorkspaceWatcher *Watcher;
void BeginSharedWorkspace()
{
    Watcher = [[WorkspaceWatcher alloc] init];
}

void SharedWorkspaceActivateApplication(pid_t PID)
{
    NSRunningApplication *Application = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
    if(Application)
    {
        [Application activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }
}

bool SharedWorkspaceIsApplicationActive(pid_t PID)
{
    Boolean Result = NO;
    NSRunningApplication *Application = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
    if(Application)
    {
        Result = [Application isActive];
    }

    return Result == YES;
}

bool SharedWorkspaceIsApplicationHidden(pid_t PID)
{
    Boolean Result = NO;
    NSRunningApplication *Application = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
    if(Application)
    {
        Result = [Application isHidden];
    }

    return Result == YES;
}

internal workspace_application_details *
BeginWorkspaceApplicationDetails(NSNotification *Notification)
{
    workspace_application_details *Info =
                    (workspace_application_details *) malloc(sizeof(workspace_application_details));
    memset(Info, 0, sizeof(workspace_application_details));

    const char *Name = [[[Notification.userInfo objectForKey:NSWorkspaceApplicationKey] localizedName] UTF8String];
    Info->PID = [[Notification.userInfo objectForKey:NSWorkspaceApplicationKey] processIdentifier];
    GetProcessForPID(Info->PID, &Info->PSN);

    if(Name)
    {
        unsigned int Length = strlen(Name);
        Info->ProcessName = (char *) malloc(Length + 1);
        strncpy(Info->ProcessName, (char *) Name, Length);
        Info->ProcessName[Length] = '\0';
    }
    else
    {
        Info->ProcessName = strdup("<Unknown Name>");
    }

    return Info;
}

void EndWorkspaceApplicationDetails(workspace_application_details *Info)
{
    if(Info)
    {
        if(Info->ProcessName)
        {
            free(Info->ProcessName);
        }

        free(Info);
    }
}

/* NOTE(koekeishiya): Subscribe to necessary notifications from NSWorkspace */
@implementation WorkspaceWatcher
- (id)init
{
    if ((self = [super init]))
    {
       [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                selector:@selector(activeDisplayDidChange:)
                name:@"NSWorkspaceActiveDisplayDidChangeNotification"
                object:nil];

       [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                selector:@selector(activeSpaceDidChange:)
                name:NSWorkspaceActiveSpaceDidChangeNotification
                object:nil];

       [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                selector:@selector(didActivateApplication:)
                name:NSWorkspaceDidActivateApplicationNotification
                object:nil];

       [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                selector:@selector(didHideApplication:)
                name:NSWorkspaceDidHideApplicationNotification
                object:nil];

       [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                selector:@selector(didUnhideApplication:)
                name:NSWorkspaceDidUnhideApplicationNotification
                object:nil];
    }

    return self;
}

- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [super dealloc];
}

- (void)activeDisplayDidChange:(NSNotification *)notification
{
    ConstructEvent(ChunkWM_DisplayChanged, NULL, false);
}

- (void)activeSpaceDidChange:(NSNotification *)notification
{
    ConstructEvent(ChunkWM_SpaceChanged, NULL, false);
}

- (void)didActivateApplication:(NSNotification *)notification
{
    workspace_application_details *Info = BeginWorkspaceApplicationDetails(notification);
    ConstructEvent(ChunkWM_ApplicationActivated, Info, false);
}

- (void)didHideApplication:(NSNotification *)notification
{
    workspace_application_details *Info = BeginWorkspaceApplicationDetails(notification);
    ConstructEvent(ChunkWM_ApplicationHidden, Info, false);
}

- (void)didUnhideApplication:(NSNotification *)notification
{
    workspace_application_details *Info = BeginWorkspaceApplicationDetails(notification);
    ConstructEvent(ChunkWM_ApplicationVisible, Info, false);
}

@end
