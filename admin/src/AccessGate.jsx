import React,{useEffect,useRef,useState} from 'react';
import {signOut} from 'firebase/auth';
import {ShieldCheck} from 'lucide-react';
import {auth} from './firebase';
export function AccessGate({user,checkAdmin,onAllowed,errorMessage}) {
  const [error,setError]=useState(''),[busy,setBusy]=useState(true);
  const mounted=useRef(false),lock=useRef(false),callbacks=useRef({checkAdmin,onAllowed,errorMessage});
  callbacks.current={checkAdmin,onAllowed,errorMessage};
  async function check(){
    if(lock.current)return;lock.current=true;setBusy(true);setError('');
    try{await user.getIdToken(true);await callbacks.current.checkAdmin();if(mounted.current&&auth.currentUser?.uid===user.uid)callbacks.current.onAllowed();}
    catch(e){if(mounted.current)setError(e.code?.startsWith('auth/')?callbacks.current.errorMessage(e):e.message);}
    finally{lock.current=false;if(mounted.current)setBusy(false);}
  }
  useEffect(()=>{mounted.current=true;check();return()=>{mounted.current=false;};},[user.uid]);
  return <div className="access"><ShieldCheck size={40}/><h1>{busy?'Opening your dashboard…':'Could not open dashboard'}</h1><p role="status">{error||'Checking your admin account.'}</p>{error&&!busy&&<><button className="primary" onClick={check}>Retry</button><button onClick={()=>signOut(auth)}>Sign out</button></>}</div>;
}
