import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import {createApp} from '../src/app.js';
import {createSuggestionProvider} from '../src/suggestions.js';
const input={name:'Ankit',eventType:'Birthday',relation:'Friend',language:'Hinglish',tone:'Warm',budget:'500',interests:'books',variant:0};
const answer={wish:'Happy birthday Ankit, have a wonderful day!',gifts:Array.from({length:3},(_,i)=>({title:`Gift idea ${i}`,reason:'A thoughtful personal choice.'}))};
const make=provider=>createApp({pool:{},verifyToken:async t=>({uid:t}),suggestions:provider});
test('suggestions require auth and reject private/unknown fields',async()=>{
 const app=make(async()=>answer);
 await request(app).post('/v1/suggestions').send(input).expect(401);
 await request(app).post('/v1/suggestions').set('Authorization','Bearer alice').send({...input,phoneNumber:'123'}).expect(400);
 await request(app).post('/v1/suggestions').set('Authorization','Bearer alice').send({...input,interests:'x'.repeat(161)}).expect(400);
 const r=await request(app).post('/v1/suggestions').set('Authorization','Bearer alice').send(input).expect(200);
 assert.equal(r.body.source,'ai');assert.equal(r.body.gifts.length,3);
});
test('unconfigured or invalid AI never masquerades as a successful result',async()=>{
 assert.equal(createSuggestionProvider({key:'',model:''}),null);
 await request(make(null)).post('/v1/suggestions').set('Authorization','Bearer a').send(input).expect(503);
 const r=await request(make(async()=>({wish:'bad',gifts:[]}))).post('/v1/suggestions').set('Authorization','Bearer a').send(input).expect(503);
 assert.deepEqual(r.body,{error:'ai_unavailable'});
});
test('AI limiter is per authenticated account',async()=>{
 let calls=0;const app=make(async()=>{calls++;return answer;});
 for(let i=0;i<6;i++)await request(app).post('/v1/suggestions').set('Authorization','Bearer a').send(input).expect(200);
 await request(app).post('/v1/suggestions').set('Authorization','Bearer a').send(input).expect(429);
 await request(app).post('/v1/suggestions').set('Authorization','Bearer b').send(input).expect(200);
 assert.equal(calls,7);
});
test('Gemini adapter uses server-only auth, structured output and rejects truncated output',async()=>{
 let body;
 const provider=createSuggestionProvider({key:'test-secret',model:'test-model',fetchImpl:async(url,options)=>{
  assert.ok(!url.includes('test-secret'));assert.equal(options.headers['x-goog-api-key'],'test-secret');body=JSON.parse(options.body);
  return {ok:true,json:async()=>({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(answer)}]}}]})};
 }});
 assert.deepEqual(await provider(input),answer);assert.ok(body.generationConfig.responseJsonSchema);assert.match(body.systemInstruction.parts[0].text,/Hinglish means conversational Hindi/);assert.match(body.systemInstruction.parts[0].text,/at most 25 words/);assert.equal(JSON.parse(body.contents[0].parts[0].text).name,'Ankit');
 const bad=createSuggestionProvider({key:'test',model:'test',fetchImpl:async()=>({ok:true,json:async()=>({candidates:[{finishReason:'MAX_TOKENS'}]})})});
 await assert.rejects(()=>bad(input));
});
