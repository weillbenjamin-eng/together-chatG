'use client';
export default function GlobalError({reset}:{error:Error;reset:()=>void}) {return <html lang="en"><body><main id="main"><h1>Together could not load</h1><button onClick={reset}>Try again</button></main></body></html>;}
