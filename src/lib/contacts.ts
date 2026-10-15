import { createCipheriv, createDecipheriv, createHmac, randomBytes } from 'node:crypto';
function key(value: string | undefined) { if (!value || !/^[a-f0-9]{64}$/i.test(value)) throw new Error('Private contact storage is not configured. Ask the owner to configure the encryption keys.'); return Buffer.from(value,'hex'); }
export function sealContact(value: string) {
 const encryptionKey=key(process.env.CONTACT_ENCRYPTION_KEY); const hashKey=key(process.env.CONTACT_HASH_KEY);
 if (encryptionKey.equals(hashKey)) throw new Error('Contact encryption and hash keys must be different.');
 const normalized=value.includes('@') ? value.trim().toLowerCase() : value.trim();
 const iv=randomBytes(12); const cipher=createCipheriv('aes-256-gcm',encryptionKey,iv);
 const encrypted=Buffer.concat([cipher.update(normalized,'utf8'),cipher.final()]);
 return { encrypted_value: ['v1',iv.toString('hex'),cipher.getAuthTag().toString('hex'),encrypted.toString('hex')].join(':'), contact_hash:createHmac('sha256',hashKey).update(normalized).digest('hex'), contact_type:normalized.includes('@')?'email':'phone' };
}
export function openContact(value:string) { const [version,iv,tag,data]=value.split(':'); if(version!=='v1') throw new Error('Invalid envelope'); const decipher=createDecipheriv('aes-256-gcm',key(process.env.CONTACT_ENCRYPTION_KEY),Buffer.from(iv,'hex')); decipher.setAuthTag(Buffer.from(tag,'hex')); return Buffer.concat([decipher.update(Buffer.from(data,'hex')),decipher.final()]).toString('utf8'); }
