'use client';
export default function ErrorPage({reset}:{error:Error;reset:()=>void}){return <main id="main"><h1>Something went wrong</h1><p>Your changes may not have been saved. Try again.</p><button onClick={reset}>Try again</button></main>;}
