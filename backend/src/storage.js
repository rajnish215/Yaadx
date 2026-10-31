import {S3Client,PutObjectCommand,GetObjectCommand,HeadObjectCommand} from '@aws-sdk/client-s3';
import {getSignedUrl} from '@aws-sdk/s3-request-presigner';
export function createStorage(){
 if(!process.env.S3_BUCKET) return null;
 const client=new S3Client({region:process.env.AWS_REGION||'auto',endpoint:process.env.S3_ENDPOINT||undefined,forcePathStyle:process.env.S3_PATH_STYLE==='true'});
 const Bucket=process.env.S3_BUCKET;
 return {
  upload:(key,type,size)=>getSignedUrl(client,new PutObjectCommand({Bucket,Key:key,ContentType:type,ContentLength:size}),{expiresIn:300}),
  download:(key)=>getSignedUrl(client,new GetObjectCommand({Bucket,Key:key}),{expiresIn:300}),
  inspect:(key)=>client.send(new HeadObjectCommand({Bucket,Key:key})),
 };
}
