#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "MMDViewer-Swift.h"
#import "PhysicsSolver.h"
#include "btBulletDynamicsCommon.h"

namespace {
    
    btVector3 glkvec2btvec(GLKVector3 from)
    {
        return btVector3(from.x, from.y, from.z);
    }
    
    btQuaternion glkq2btq(GLKQuaternion from)
    {
        return btQuaternion(from.x, from.y, from.z, from.w);
    }
    
}

@interface PhysicsSolver: NSObject <PhysicsSolving>
@property (nonatomic, copy, readonly) NSArray<RigidBody*>* rigidBodies;
@property (nonatomic, copy, readonly) NSArray<Constraint*>* constraints;
@property (nonatomic, copy, readonly) NSArray<Bone*>* bones;

- (void) build:(NSArray<RigidBody*>*)rigidBodies constraints:(NSArray<Constraint*>*)constraints bones:(NSArray<Bone*>*)bones;
- (void) step;
- (void) move:(int)boneIndex rot:(GLKQuaternion)rot pos:(GLKVector3)pos;
- (void) getTransform:(int)boneIndex rot:(GLKQuaternion*)rot pos:(GLKVector3*)pos;
@end

@interface PhysicsSolver () {
    btDefaultCollisionConfiguration* _collisionConfiguration;
    btCollisionDispatcher* _dispatcher;
    btBroadphaseInterface* _overlappingPairCache;
    btSequentialImpulseConstraintSolver* _solver;
    btAlignedObjectArray<btCollisionShape*> _collisionShapes;
    btAlignedObjectArray<btRigidBody*> _btRigidBodies;
    btDiscreteDynamicsWorld* _dynamicsWorld;
}
@property (nonatomic, readwrite) NSArray<RigidBody*>* rigidBodies;
@property (nonatomic, readwrite) NSArray<Constraint*>* constraints;
@property (nonatomic, readwrite) NSArray<Bone*>* bones;
@end

@implementation PhysicsSolver

- (instancetype) init
{
    if (self = [super init])
    {
        _collisionConfiguration = new btDefaultCollisionConfiguration();
        _dispatcher = new btCollisionDispatcher(_collisionConfiguration);
        _overlappingPairCache = new btDbvtBroadphase();
        _solver = new btSequentialImpulseConstraintSolver;
        
        _dynamicsWorld = new btDiscreteDynamicsWorld(_dispatcher,
                                                     _overlappingPairCache,
                                                     _solver,
                                                     _collisionConfiguration);
        _dynamicsWorld->setGravity(btVector3(0, -9.8, 0));
    }
    
    return self;
}

- (void) dealloc
{
    for (int i = _dynamicsWorld->getNumCollisionObjects() - 1; i >= 0 ; i--)
    {
        btCollisionObject* obj = _dynamicsWorld->getCollisionObjectArray()[i];
        btRigidBody* aBtRigidBody = btRigidBody::upcast(obj);
        if (aBtRigidBody && aBtRigidBody->getMotionState())
        {
            delete aBtRigidBody->getMotionState();
        }
        _dynamicsWorld->removeCollisionObject(obj);
        delete obj;
    }
    
    for (int i = 0; i < _collisionShapes.size(); i++)
    {
        btCollisionShape* shape = _collisionShapes[i];
        _collisionShapes[i] = 0;
        delete shape;
    }
    
    delete _dynamicsWorld;
    delete _solver;
    delete _overlappingPairCache;
    delete _dispatcher;
    delete _collisionConfiguration;
    
    _collisionShapes.clear();
}

- (void) buildWithRigidBody:(RigidBody*)rigidBody bones:(NSArray<Bone*>*)bones
{
    btCollisionShape * shape = nullptr;
    if (rigidBody.shapeType == 0)
    {
        shape = new btSphereShape(btScalar(rigidBody.size.x));
    }
    else if (rigidBody.shapeType == 1)
    {
        shape = new btBoxShape(glkvec2btvec(rigidBody.size));
    }
    else if (rigidBody.shapeType == 2)
    {
        shape = new btCapsuleShape(btScalar(rigidBody.size.x), btScalar(rigidBody.size.y));
    }
    else
    {
        NSLog(@"Unknown rigid body shape: %d", (int)rigidBody.shapeType);
        return;
    }
    
    _collisionShapes.push_back(shape);
    
    btScalar mass(rigidBody.type == 0 ? 0 : (rigidBody.mass != 0 ? rigidBody.mass : 1));
    btVector3 localInertia(0, 0, 0);
    
    if (mass != 0)
    {
        shape->calculateLocalInertia(mass, localInertia);
    }
    
    btTransform startTransform;
    startTransform.setIdentity();
    startTransform.setOrigin(glkvec2btvec(rigidBody.pos));
    btMatrix3x3	btmRotationMat;
    btmRotationMat.setEulerZYX(rigidBody.rot.x, rigidBody.rot.y, rigidBody.rot.z);
    startTransform.setBasis(btmRotationMat);
    btDefaultMotionState* motionState = new btDefaultMotionState(startTransform);
    
    btRigidBody::btRigidBodyConstructionInfo rbInfo(mass, motionState, shape, localInertia);
    rbInfo.m_linearDamping = rigidBody.linearDamping;
    rbInfo.m_angularDamping = rigidBody.angularDamping;
    rbInfo.m_restitution = rigidBody.restitution;
    rbInfo.m_friction = rigidBody.friction;
    
    btRigidBody* aBtRigidBody = new btRigidBody(rbInfo);
    if (rigidBody.type == 0)
    {
        aBtRigidBody->setCollisionFlags(aBtRigidBody->getCollisionFlags() | btCollisionObject::CF_KINEMATIC_OBJECT);
        aBtRigidBody->setActivationState(DISABLE_DEACTIVATION);
    }
    aBtRigidBody->setSleepingThresholds(0.0f, 0.0f);
    aBtRigidBody->setUserPointer((__bridge void*)rigidBody);
    
    _dynamicsWorld->addRigidBody(aBtRigidBody, 1 << rigidBody.groupID, rigidBody.groupFlag);
    _btRigidBodies.push_back(aBtRigidBody);
}

- (void) buildWithConstraint:(Constraint*)constraint
{
    btMatrix3x3 btmRotationMat;
    btmRotationMat.setEulerZYX(constraint.rot.x, constraint.rot.y, constraint.rot.z);
    btTransform bttrTransform;
    bttrTransform.setIdentity();
    bttrTransform.setOrigin(glkvec2btvec(constraint.pos));
    bttrTransform.setBasis( btmRotationMat );
    
    btTransform frameInA = _btRigidBodies[(int)constraint.rigidAIndex]->getWorldTransform().inverse();
    btTransform frameInB = _btRigidBodies[(int)constraint.rigidBIndex]->getWorldTransform().inverse();
    frameInA = frameInA * bttrTransform;
    frameInB = frameInB * bttrTransform;
    
    const bool useLinearReferenceFrame = true;
    btGeneric6DofSpringConstraint * aBtConstraint = new btGeneric6DofSpringConstraint(
                                                                                      *_btRigidBodies[(int)constraint.rigidAIndex],
                                                                                      *_btRigidBodies[(int)constraint.rigidBIndex],
                                                                                      frameInA,
                                                                                      frameInB,
                                                                                      useLinearReferenceFrame);
    
    aBtConstraint->setLinearLowerLimit(glkvec2btvec(constraint.linearLowerLimit));
    aBtConstraint->setLinearUpperLimit(glkvec2btvec(constraint.linearUpperLimit));
    aBtConstraint->setAngularLowerLimit(glkvec2btvec(constraint.angularLowerLimit));
    aBtConstraint->setAngularUpperLimit(glkvec2btvec(constraint.angularUpperLimit));
    
    if (constraint.linearSpringStiffness.x != 0) {
        aBtConstraint->enableSpring(0, true);
        aBtConstraint->setStiffness(0, constraint.linearSpringStiffness.x);
    }
    if (constraint.linearSpringStiffness.y != 0) {
        aBtConstraint->enableSpring(1, true);
        aBtConstraint->setStiffness(1, constraint.linearSpringStiffness.y);
    }
    if (constraint.linearSpringStiffness.z != 0) {
        aBtConstraint->enableSpring(2, true);
        aBtConstraint->setStiffness(2, constraint.linearSpringStiffness.z);
    }
    
    aBtConstraint->enableSpring(3, true);
    aBtConstraint->setStiffness(3, constraint.angularSpringStiffness.x);
    
    aBtConstraint->enableSpring(4, true);
    aBtConstraint->setStiffness(4, constraint.angularSpringStiffness.y);
    
    aBtConstraint->enableSpring(5, true);
    aBtConstraint->setStiffness(5, constraint.angularSpringStiffness.z);
    
    _dynamicsWorld->addConstraint(aBtConstraint);
}

- (void) build:(NSArray<RigidBody*>*)rigidBodies constraints:(NSArray<Constraint*>*)constraints bones:(NSArray<Bone*>*)bones
{
    self.rigidBodies = rigidBodies;
    self.constraints = constraints;
    self.bones = bones;
    
    for (RigidBody * rigidBody in rigidBodies)
    {
        [self buildWithRigidBody:rigidBody bones:bones];
    }
    
    for (Constraint * constraint in constraints)
    {
        [self buildWithConstraint:constraint];
    }
}

- (void) move:(int)boneIndex rot:(GLKQuaternion)rot pos:(GLKVector3)pos
{
    for (RigidBody * rigidBody in self.rigidBodies)
    {
        if (rigidBody.boneIndex != boneIndex)
        {
            continue;
        }
        
        if (rigidBody.type != 0)
        {
            continue;
        }
        
        void * pointer = (__bridge void*)rigidBody;
        
        for (int i = 0; i < _btRigidBodies.size(); i++)
        {
            if (_btRigidBodies[i]->getUserPointer() != pointer)
            {
                continue;
            }
            
            btRigidBody * body = _btRigidBodies[i];
            btTransform worldTransform;
            worldTransform.setOrigin(glkvec2btvec(pos));
            worldTransform.setRotation(glkq2btq(rot));
            
            Bone * bone = _bones[rigidBody.boneIndex];
            
            btTransform offset;
            offset.setIdentity();
            offset.setOrigin(btVector3(rigidBody.pos.x - bone.pos.x, rigidBody.pos.y - bone.pos.y, rigidBody.pos.z - bone.pos.z));
            btMatrix3x3	btmRotationMat;
            btmRotationMat.setEulerZYX(rigidBody.rot.x, rigidBody.rot.y, rigidBody.rot.z);
            offset.setBasis(btmRotationMat);
            
            worldTransform = worldTransform * offset;
            
            if (body->getMotionState())
            {
                body->getMotionState()->setWorldTransform(worldTransform);
                
            }
            else
            {
                body->setWorldTransform(worldTransform);
            }
        }
    }
}

- (void) getTransform:(int)boneIndex rot:(GLKQuaternion*)rot pos:(GLKVector3*)pos
{
    for (RigidBody * rigidBody in self.rigidBodies)
    {
        if (rigidBody.boneIndex != boneIndex)
        {
            continue;
        }
        
        void * pointer = (__bridge void*)rigidBody;
        
        for (int i = 0; i < _btRigidBodies.size(); i++)
        {
            if (_btRigidBodies[i]->getUserPointer() != pointer)
            {
                continue;
            }
            
            btRigidBody * body = _btRigidBodies[i];
            
            btTransform trans;
            if (body->getMotionState())
            {
                body->getMotionState()->getWorldTransform(trans);
                
            }
            else
            {
                trans = body->getWorldTransform();
            }
            
            Bone * bone = self.bones[rigidBody.boneIndex];
            
            btTransform offset;
            offset.setIdentity();
            offset.setOrigin(btVector3(rigidBody.pos.x - bone.pos.x, rigidBody.pos.y - bone.pos.y, rigidBody.pos.z - bone.pos.z));
            btMatrix3x3	btmRotationMat;
            btmRotationMat.setEulerZYX(rigidBody.rot.x, rigidBody.rot.y, rigidBody.rot.z);
            offset.setBasis(btmRotationMat);
            
            trans = trans * offset.inverse();
            
            const btVector3 & bodyPos = trans.getOrigin();
            const btQuaternion & bodyRot = trans.getRotation();
            //
            pos->x = bodyPos.x();
            pos->y = bodyPos.y();
            pos->z = bodyPos.z();
            //
            rot->x = bodyRot.getX();
            rot->y = bodyRot.getY();
            rot->z = bodyRot.getZ();
            rot->w = bodyRot.getW();
        }
    }
}

- (void) step
{
    _dynamicsWorld->stepSimulation(1.f / 30.f, 2, 1.f / 60.f);
}

@end

#ifdef __cplusplus
extern "C" {
#endif
    
    id PhysicsSolverMake() {
        return [[PhysicsSolver alloc] init];
    }
    
#ifdef __cplusplus
}
#endif
