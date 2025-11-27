AWSTemplateFormatVersion: “2010-09-09”
Transform: AWS::Serverless-2016-10-31

Parameters:
EnvironmentName:
Type: String
Default: Production
Description: Environment name

Resources:

# VPC

VPC:
Type: AWS::EC2::VPC
Properties:
CidrBlock: 10.0.0.0/16
EnableDnsHostnames: true
EnableDnsSupport: true
Tags:
- Key: Name
Value: !Sub “${EnvironmentName}-VPC”

# Subnets

VPCSubnet1:
Type: AWS::EC2::Subnet
Properties:
VpcId: !Ref VPC
CidrBlock: 10.0.1.0/24
AvailabilityZone: !Select [0, !GetAZs “”]
Tags:
- Key: Name
Value: !Sub “${EnvironmentName}-Subnet1”

VPCSubnet2:
Type: AWS::EC2::Subnet
Properties:
VpcId: !Ref VPC
CidrBlock: 10.0.2.0/24
AvailabilityZone: !Select [1, !GetAZs “”]
Tags:
- Key: Name
Value: !Sub “${EnvironmentName}-Subnet2”

# Internet Gateway

InternetGateway:
Type: AWS::EC2::InternetGateway
Properties:
Tags:
- Key: Name
Value: !Sub “${EnvironmentName}-IGW”

AttachGateway:
Type: AWS::EC2::VPCGatewayAttachment
Properties:
VpcId: !Ref VPC
InternetGatewayId: !Ref InternetGateway

# Route Table

RouteTable:
Type: AWS::EC2::RouteTable
Properties:
VpcId: !Ref VPC
Tags:
- Key: Name
Value: !Sub “${EnvironmentName}-RouteTable”

Route:
Type: AWS::EC2::Route
DependsOn: AttachGateway
Properties:
RouteTableId: !Ref RouteTable
DestinationCidrBlock: 0.0.0.0/0
GatewayId: !Ref InternetGateway

SubnetRouteTableAssociation1:
Type: AWS::EC2::SubnetRouteTableAssociation
Properties:
SubnetId: !Ref VPCSubnet1
RouteTableId: !Ref RouteTable

SubnetRouteTableAssociation2:
Type: AWS::EC2::SubnetRouteTableAssociation
Properties:
SubnetId: !Ref VPCSubnet2
RouteTableId: !Ref RouteTable

# ALB Security Group

ALBSecurityGroup:
Type: AWS::EC2::SecurityGroup
Properties:
GroupDescription: Security group for ALB
VpcId: !Ref VPC
SecurityGroupIngress:
- IpProtocol: tcp
FromPort: 80
ToPort: 80
CidrIp: 0.0.0.0/0
Description: Allow HTTP
- IpProtocol: tcp
FromPort: 443
ToPort: 443
CidrIp: 0.0.0.0/0
Description: Allow HTTPS
Tags:
- Key: Name
Value: !Sub “${EnvironmentName}-ALBSecurityGroup”

# ALB

ALB:
Type: AWS::ElasticLoadBalancingV2::LoadBalancer
Properties:
Name: !Sub “${EnvironmentName}-alb”
Scheme: internet-facing
SecurityGroups:
- !Ref ALBSecurityGroup
Subnets:
- !Ref VPCSubnet1
- !Ref VPCSubnet2
Tags:
- Key: Environment
Value: !Ref EnvironmentName

# Target Group

MyTargetGroup:
Type: AWS::ElasticLoadBalancingV2::TargetGroup
Properties:
Name: !Sub “${EnvironmentName}-tg”
Port: 80
Protocol: HTTP
VpcId: !Ref VPC
TargetType: instance
HealthCheckProtocol: HTTP
HealthCheckPort: 80
HealthCheckPath: /
HealthCheckIntervalSeconds: 30
HealthyThresholdCount: 3
UnhealthyThresholdCount: 2
Matcher:
HttpCode: “200-299”
Tags:
- Key: Environment
Value: !Ref EnvironmentName

# Listener

MyListener:
Type: AWS::ElasticLoadBalancingV2::Listener
Properties:
LoadBalancerArn: !Ref ALB
Port: 80
Protocol: HTTP
DefaultActions:
- Type: forward
TargetGroupArn: !Ref MyTargetGroup

Outputs:
LoadBalancerDNS:
Description: DNS name of the load balancer
Value: !GetAtt ALB.DNSName
Export:
Name: !Sub “${EnvironmentName}-ALB-DNS”

TargetGroupArn:
Description: ARN of the target group
Value: !Ref MyTargetGroup
Export:
Name: !Sub “${EnvironmentName}-TargetGroup-ARN”