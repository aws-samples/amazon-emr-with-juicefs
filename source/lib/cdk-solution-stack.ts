/**
 *  Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance
 *  with the License. A copy of the License is located at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  or in the 'license' file accompanying this file. This file is distributed on an 'AS IS' BASIS, WITHOUT WARRANTIES
 *  OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions
 *  and limitations under the License.
 */

import * as emr from '@aws-cdk/aws-emr';
import * as iam from '@aws-cdk/aws-iam';
import * as cdk from '@aws-cdk/core';
import * as ec2 from '@aws-cdk/aws-ec2';
import * as s3 from '@aws-cdk/aws-s3';

import { CfnCluster } from '@aws-cdk/aws-emr';
import { Aws, CfnOutput, CfnParameter, CfnParameterProps } from '@aws-cdk/core';
import { CfnNatGateway } from '@aws-cdk/aws-ec2';
import * as utils from './utils';

export enum ReleaseLabel {
  RELEASE_6_1_0 = 'emr-6.1.0',
  RELEASE_5_31_0 = 'emr-5.31.0',
}

export interface EMRClusterProps {
  readonly name?: string;
  readonly ec2KeyName?: string;
  readonly ec2SubnetId?: string;
  readonly visibleToAllUsers?: boolean;
  readonly releaseLabel?: ReleaseLabel;

  readonly masterInstanceGroup?: CfnCluster.InstanceGroupConfigProperty;
  readonly coreInstanceGroup?: CfnCluster.InstanceGroupConfigProperty;

  readonly emrManagedMasterSecurityGroup?: string;
  readonly emrManagedSlaveSecurityGroup?: string;
  readonly serviceAccessSecurityGroup?: string;

  readonly jobFlowRoleProfile?: iam.CfnInstanceProfile;
  readonly serviceRole?: iam.Role;

  readonly bootstrapActions?: Array<CfnCluster.BootstrapActionConfigProperty | cdk.IResolvable>;
  readonly configurations?: Array<CfnCluster.ConfigurationProperty | cdk.IResolvable>;

  readonly applications?: Array<CfnCluster.ApplicationProperty | cdk.IResolvable>;
  readonly logUri?: string;
}

export class EMRCluster extends cdk.Construct {
  readonly clusterId: string;

  constructor(scope: cdk.Construct, id: string, props: EMRClusterProps = {}) {
    super(scope, id);

    const cluster = new emr.CfnCluster(this, 'EMRCluster', {
      name: props.name ?? id,
      instances: {
        ec2SubnetId: props.ec2SubnetId,
        terminationProtected: false,
        masterInstanceGroup: props.masterInstanceGroup,
        coreInstanceGroup: props.coreInstanceGroup,
        emrManagedMasterSecurityGroup: props.emrManagedMasterSecurityGroup,
        emrManagedSlaveSecurityGroup: props.emrManagedSlaveSecurityGroup,
        serviceAccessSecurityGroup: props.serviceAccessSecurityGroup,
      },
      visibleToAllUsers: props.visibleToAllUsers,
      releaseLabel: (props.releaseLabel ?? ReleaseLabel.RELEASE_6_1_0).valueOf(),
      jobFlowRole: (props.jobFlowRoleProfile ?? this._defaultJobFlowRoleProfile).ref,
      serviceRole: (props.serviceRole ?? this._defaultServiceRole).roleArn,
      bootstrapActions: props.bootstrapActions,
      configurations: props.configurations,
      applications: props.applications,
      logUri: props.logUri,
    });

    this.clusterId = cluster.ref;
  }

  private get _defaultJobFlowRoleProfile(): iam.CfnInstanceProfile {
    return new iam.CfnInstanceProfile(this, 'EMRClusterinstanceProfile', {
      roles: [
        new iam.Role(this, 'EMRClusterinstanceProfileRole', {
          assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
          managedPolicies: [
            iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonElasticMapReduceforEC2Role'),
          ],
        }).roleName,
      ],
    });
  }

  private get _defaultServiceRole(): iam.Role {
    return new iam.Role(this, 'EMRClusterServiceRole', {
      assumedBy: new iam.ServicePrincipal(`elasticmapreduce.${Aws.URL_SUFFIX}`),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonElasticMapReduceRole'),
      ],
    });
  }

}

function assertenv(...env: string[]) {
  for (const e of env) {
    if (!process.env[e]) {
      throw new Error(`Env ${e} is not set!`);
    }
  }
}

function paramGroup(label: string, params: (CfnParameter | undefined)[]) {
  return {
    Label: { default: label },
    Parameters: params.map(p => {
      return p ? p.logicalId : '';
    }).filter(id => id),
  };
}

export class AwsEMRwithJuiceFSConstructsStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    assertenv('BUCKET_NAME', 'SOLUTION_NAME', 'VERSION');

    const cfnParam = (id_: string, props_?: CfnParameterProps): CfnParameter => new CfnParameter(this, id_, props_);
    const { BUCKET_NAME, SOLUTION_NAME, VERSION } = process.env;

    const juiceFSAccessTokenParam = cfnParam('JuiceFSAccessToken', {
      type: 'String',
      description: 'The access token of JuiceFS volume',
      noEcho: true,
      minLength: 30,
    });
    const juiceFSVolumeNameParam = cfnParam('JuiceFSVolumeName', {
      type: 'String',
      description: 'The volume name of JuiceFS',
      minLength: 1,
    });
    const juiceFSCacheDirParam = cfnParam('JuiceFSCacheDir', {
      type: 'String',
      description: 'The cache directory of JuiceFS Java Client, you could specify more than one folder, seperate by colon, or use wildcards *',
      minLength: 3,
      default: '/mnt*/jfs',
    });
    const juiceFSCacheSizeParam = cfnParam('JuiceFSCacheSize', {
      type: 'Number',
      description: 'Cache capacity (unit MB), if multiple diectories are configured, this is total capacity for all cache folders',
      minValue: 0,
      default: '10240',
    });
    const juiceFSCacheFullBlock = cfnParam('JuiceFSCacheFullBlock', {
      type: 'String',
      description: 'Whether to cache sequential read data, set to false when disk space is limited or disk performance is low',
      allowedValues: ['true', 'false'],
      default: 'false',
    });
    const clusterNameParam = cfnParam('EMRClusterName', {
      type: 'String',
      description: 'The cluster name',
      minLength: 5,
      default: 'EMRwithJuiceFS',
    });
    const masterInstanceTypeParam = cfnParam('MasterInstanceType', {
      type: 'String',
      description: 'Instance type to be used for the master instance',
      allowedValues: utils.SupportedInstanceTypes,
      default: 'm5.xlarge',
    });
    const coreInstanceTypeParam = cfnParam('CoreInstanceType', {
      type: 'String',
      description: 'Instance type to be used for the core instances',
      allowedValues: utils.SupportedInstanceTypes,
      default: 'm5.xlarge',
    });
    const numberOfCoreInstancesParam = cfnParam('NumberOfCoreInstances', {
      type: 'Number',
      description: 'Number of core instances',
      default: 3,
    });
    // const enableS3ConsistentView = cfnParam('EnableS3ConsistentView', {
    //   type: 'String',
    //   description: 'Whether to enable s3 consistent view',
    //   allowedValues: ['true', 'false'],
    //   default: 'false',
    // });

    this.templateOptions.description = `(SO8008) - Amazon EMR with JuiceFS version ${VERSION}`;
    this.templateOptions.metadata = {
      'AWS::CloudFormation::Interface': {
        ParameterGroups: [
          paramGroup('Cluster Settings', [
            clusterNameParam,
            masterInstanceTypeParam,
            coreInstanceTypeParam,
            numberOfCoreInstancesParam,
          ]),
          paramGroup('JuiceFS Configurations', [
            juiceFSAccessTokenParam,
            juiceFSVolumeNameParam,
            juiceFSCacheDirParam,
            juiceFSCacheSizeParam,
            juiceFSCacheFullBlock,
          ]),
        ],
      },
    };

    const bucketName = `juicefs-${juiceFSVolumeNameParam.valueAsString}`;
    const logBucket = new s3.Bucket(this, 'LogBucket');

    const vpc = new ec2.Vpc(this, 'Vpc', {
      cidr: '10.0.0.0/21',
      natGateways: 1,
      maxAzs: 1,
      subnetConfiguration: [
        {
          subnetType: ec2.SubnetType.PUBLIC,
          name: 'Ingress',
          cidrMask: 24,
        },
        {
          subnetType: ec2.SubnetType.PRIVATE,
          name: 'Application',
          cidrMask: 24,
        },
      ],
      gatewayEndpoints: {
        S3: { service: ec2.GatewayVpcEndpointAwsService.S3 },
      },
    });

    const pubSubnet = vpc.publicSubnets[0];
    const privSubnet = vpc.privateSubnets[0];
    const natgw = pubSubnet.node.findChild('NATGateway') as CfnNatGateway;

    const masterBootScript = `#!/bin/bash -xe
      exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
      set -xe
      curl -fsSL https://s.juicefs.com/static/emr-boot.sh -o /tmp/emr-boot.sh && bash /tmp/emr-boot.sh --cache-dir "${juiceFSCacheDirParam.valueAsString}"
      curl -fsSL https://juicefs.com/static/juicefs -o /usr/bin/juicefs && chmod +x /usr/bin/juicefs
      echo "export JFS_VOL=${juiceFSVolumeNameParam.valueAsString}" > /etc/profile.d/jfs.sh
      echo "export AWS_DEFAULT_REGION=${Aws.REGION}" >> /etc/profile.d/jfs.sh
    `;
    const coreBootScript = `#!/bin/bash -xe
      exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
      set -xe
      curl -fsSL https://s.juicefs.com/static/emr-boot.sh -o /tmp/emr-boot.sh && bash /tmp/emr-boot.sh --cache-dir "${juiceFSCacheDirParam.valueAsString}"
    `;

    // https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-man-sec-groups.html#emr-sg-elasticmapreduce-master-private
    const securityGroupOfMaster = new ec2.SecurityGroup(this, 'SG-EMR-Master', { vpc });
    const securityGroupOfSlave = new ec2.SecurityGroup(this, 'SG-EMR-Slave', { vpc });
    const securityGroupOfServiceAccess = new ec2.SecurityGroup(this, 'SG-EMR-ServiceAccess', { vpc });

    securityGroupOfMaster.addIngressRule(securityGroupOfServiceAccess, ec2.Port.tcp(8443));
    securityGroupOfMaster.addIngressRule(securityGroupOfMaster, ec2.Port.tcpRange(0, 65535));
    securityGroupOfMaster.addIngressRule(securityGroupOfSlave, ec2.Port.tcpRange(0, 65535));
    securityGroupOfMaster.addIngressRule(securityGroupOfMaster, ec2.Port.udpRange(0, 65535));
    securityGroupOfMaster.addIngressRule(securityGroupOfSlave, ec2.Port.udpRange(0, 65535));
    securityGroupOfMaster.addIngressRule(securityGroupOfMaster, ec2.Port.allIcmp());
    securityGroupOfMaster.addIngressRule(securityGroupOfSlave, ec2.Port.allIcmp());

    securityGroupOfSlave.addIngressRule(securityGroupOfServiceAccess, ec2.Port.tcp(8443));
    securityGroupOfSlave.addIngressRule(securityGroupOfMaster, ec2.Port.tcpRange(0, 65535));
    securityGroupOfSlave.addIngressRule(securityGroupOfSlave, ec2.Port.tcpRange(0, 65535));
    securityGroupOfSlave.addIngressRule(securityGroupOfMaster, ec2.Port.udpRange(0, 65535));
    securityGroupOfSlave.addIngressRule(securityGroupOfSlave, ec2.Port.udpRange(0, 65535));
    securityGroupOfSlave.addIngressRule(securityGroupOfMaster, ec2.Port.allIcmp());
    securityGroupOfSlave.addIngressRule(securityGroupOfSlave, ec2.Port.allIcmp());

    securityGroupOfServiceAccess.addIngressRule(securityGroupOfMaster, ec2.Port.tcp(9443));
    securityGroupOfServiceAccess.addEgressRule(securityGroupOfMaster, ec2.Port.tcp(8443));
    securityGroupOfServiceAccess.addEgressRule(securityGroupOfSlave, ec2.Port.tcp(8443));

    const cluster = new EMRCluster(this, 'EMRwithJuiceFS', {
      name: clusterNameParam.valueAsString,
      logUri: `s3://${logBucket.bucketName}`,
      visibleToAllUsers: true,
      ec2SubnetId: privSubnet.subnetId,
      masterInstanceGroup: {
        name: 'Master',
        instanceCount: 1,
        instanceType: masterInstanceTypeParam.valueAsString,
        market: 'ON_DEMAND',
      },
      coreInstanceGroup: {
        name: 'Core',
        instanceCount: numberOfCoreInstancesParam.valueAsNumber,
        instanceType: coreInstanceTypeParam.valueAsString,
        market: 'ON_DEMAND',
      },

      emrManagedMasterSecurityGroup: securityGroupOfMaster.securityGroupId,
      emrManagedSlaveSecurityGroup: securityGroupOfSlave.securityGroupId,
      serviceAccessSecurityGroup: securityGroupOfServiceAccess.securityGroupId,

      applications: [{ name: 'Hive' }, { name: 'Spark' }, { name: 'Tez' }],
      bootstrapActions: [
        {
          name: 'BootJuiceFSOnMasterNodes',
          scriptBootstrapAction: {
            path: `s3://${Aws.REGION}.elasticmapreduce/bootstrap-actions/run-if`,
            args: [
              'instance.isMaster=true',
              'sudo', 'bash', '-c', masterBootScript,
            ],
          },
        },
        {
          name: 'BootJuiceFSOnCoreNodes',
          scriptBootstrapAction: {
            path: `s3://${Aws.REGION}.elasticmapreduce/bootstrap-actions/run-if`,
            args: [
              'instance.isMaster=false',
              'sudo', 'bash', '-c', coreBootScript,
            ],
          },
        },
        {
          name: 'InstallTPC-DSBenchmarkAssets',
          scriptBootstrapAction: {
            path: `s3://${Aws.REGION}.elasticmapreduce/bootstrap-actions/run-if`,
            args: [
              'instance.isMaster=true',
              'aws', 's3', 'cp', `s3://${BUCKET_NAME}/${SOLUTION_NAME}/${VERSION}/benchmark-sample.zip`, '/home/hadoop',
            ],
          },
        },
      ],
      configurations: [
        {
          classification: 'core-site',
          configurationProperties: {
            'fs.jfs.impl': 'com.juicefs.JuiceFileSystem',
            'fs.AbstractFileSystem.jfs.impl': 'com.juicefs.JuiceFS',
            'juicefs.free-space': '0.3',
            'juicefs.cache-size': juiceFSCacheSizeParam.valueAsString,
            'juicefs.cache-dir': juiceFSCacheDirParam.valueAsString,
            'juicefs.cache-group': 'yarn',
            'juicefs.cache-full-block': juiceFSCacheFullBlock.valueAsString,
            'juicefs.discover-nodes-url': 'yarn',
            'juicefs.token': juiceFSAccessTokenParam.valueAsString,
            'juicefs.access-log': '/tmp/juicefs.access.log',
          },
          configurations: [],
        },
        // {
        //   classification: 'emrfs-site',
        //   configurationProperties: {
        //     'fs.s3.consistent': enableS3ConsistentView.valueAsString,
        //     'fs.s3.consistent.metadata.read.capacity': '600',
        //     'fs.s3.consistent.metadata.write.capacity': '300',
        //   },
        // },
      ],
      jobFlowRoleProfile: new iam.CfnInstanceProfile(this, 'EMRClusterinstanceProfile', {
        roles: [
          new iam.Role(this, 'EMRClusterinstanceProfileRole', {
            assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
            managedPolicies: [
              iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonElasticMapReduceforEC2Role'),
              iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
            ],
            // The following policy may not be necessary because `service-role/AmazonElasticMapReduceforEC2Role`,
            // already have all the s3 permissions. It's for future extending purpose here.
            inlinePolicies: {
              JuiceFSS3Access: new iam.PolicyDocument({
                statements: [
                  new iam.PolicyStatement({
                    effect: iam.Effect.ALLOW,
                    actions: [
                      's3:PutObject',
                      's3:GetObject',
                      's3:DeleteObject',
                      's3:ListBucket',
                    ],
                    resources: [
                      `arn:${Aws.PARTITION}:s3:::${bucketName}/*`,
                      `arn:${Aws.PARTITION}:s3:::${bucketName}`,
                    ],
                  }),
                ],
              }),
            },
          }).roleName,
        ],
      }),
    });

    cluster.node.addDependency(natgw);

    new CfnOutput(this, 'ClusterID', { value: cluster.clusterId });
    new CfnOutput(this, 'LogBucketName', { value: logBucket.bucketName });
  }
}
