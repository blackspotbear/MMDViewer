#import <Foundation/Foundation.h>
#import "PhysicsSolver.h"
#import "MMDViewer-Swift.h"

@interface PhysicsSolver: NSObject <PhysicsSolving>
- (void) build:(NSArray<RigidBodyWrapper*>*)rigidBodies joints:(NSArray<JointWrapper *>*)joints;
@end

@implementation PhysicsSolver

- (void) build:(NSArray<RigidBodyWrapper*>*)rigidBodies joints:(NSArray<JointWrapper*>*)joints
{
    NSLog(@"%lu, %lu", (unsigned long)rigidBodies.count, (unsigned long)joints.count);
    
}

@end

id PhysicsSolverMake() {
    return [[PhysicsSolver alloc] init];
}
