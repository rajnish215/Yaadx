import {z} from 'zod';
export const idSchema=z.string().regex(/^[A-Za-z0-9_-]{1,128}$/);
const date=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(s=>{const d=new Date(`${s}T00:00:00Z`);return !isNaN(d)&&d.toISOString().slice(0,10)===s;});
export const reminderSchema=z.object({
 id:idSchema,name:z.string().trim().min(1).max(120),relation:z.string().max(80),phoneNumber:z.string().max(30).nullable().optional(),
 eventType:z.string().min(1).max(80),date,time:z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),note:z.string().max(4000),
 memoryCaption:z.string().max(4000),photoIds:z.array(z.uuid()).max(10),voiceId:z.uuid().nullable(),
 voiceNoteCompleted:z.boolean(),messageSent:z.boolean(),repeatYearly:z.boolean(),advanceDays:z.number().int().min(0).max(10),
 voiceAlert:z.boolean(),notificationEnabled:z.boolean(),isCompleted:z.boolean(),createdAt:z.iso.datetime({offset:true}),
}).strict();
export const mutationSchema=z.object({operationId:z.uuid(),baseVersion:z.number().int().min(0),data:reminderSchema.nullable()}).strict();
export const mediaSchema=z.object({id:z.uuid(),kind:z.enum(['photo','voice']),contentType:z.enum(['image/jpeg','image/png','image/webp','audio/mp4','audio/mpeg','audio/wav','audio/x-m4a']),byteSize:z.number().int().min(1).max(20*1024*1024)}).strict().refine(v=>v.kind==='photo'?v.contentType.startsWith('image/'):v.contentType.startsWith('audio/'));
