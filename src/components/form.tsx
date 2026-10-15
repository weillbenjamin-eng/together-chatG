'use client';
import { useActionState } from 'react';
export type Result={error?:string;success?:string;link?:string};
export function Form({action,children,label='Save',danger=false}:{action:(state:Result,data:FormData)=>Promise<Result>;children?:React.ReactNode;label?:string;danger?:boolean}) {
 const [state,dispatch,pending]=useActionState(action,{});
 return <form action={dispatch} className="stack" onSubmit={event=>{if(danger && !confirm('This changes member access. Continue?')) event.preventDefault();}}>{children}<button className={danger?'danger':''} disabled={pending}>{pending?'Working…':label}</button>{state.error && <p role="alert" className="error">{state.error}</p>}{state.success && <p role="status" className="success">{state.success}</p>}{state.link && <div><label htmlFor="invite-link">Private invitation link</label><input id="invite-link" value={state.link} readOnly onFocus={e=>e.target.select()}/><p className="muted">Copy and share privately. The link expires after seven days.</p></div>}</form>;
}
