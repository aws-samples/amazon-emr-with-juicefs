#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { AwsEMRwithJuiceFSConstructsStack } from '../lib/cdk-solution-stack';

const app = new cdk.App();
new AwsEMRwithJuiceFSConstructsStack(app, 'emr-with-juicefs');
