import './globals.css';
import type { Metadata } from 'next';
export const metadata:Metadata={title:'Together',description:'Your social life, organized.',robots:{index:false,follow:false},referrer:'no-referrer'};
export default function Layout({children}:{children:React.ReactNode}) { return <html lang="en"><body><a className="skip" href="#main">Skip to content</a>{children}</body></html>; }
