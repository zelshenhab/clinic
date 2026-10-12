import type { SupabaseClient } from '@supabase/supabase-js';
import { AppError, ResourceNotFoundError } from '../../common/errors/app-error.js';
export interface ClinicRepository { list(): Promise<unknown[]>; get(id:string): Promise<unknown>; settings(id:string): Promise<unknown>; }
export function clinicRepository(db:SupabaseClient): ClinicRepository {
 const read = async (table:string, id?:string) => {
  let query = db.from(table).select(table === 'clinics' ? 'id,slug,name,address,timezone,phone,working_hours,description,image_url,logo_url' : 'clinic_id,configuration').eq(table === 'clinics' ? 'active' : 'public', true);
  if(id) query = query.eq(table === 'clinics' ? 'id' : 'clinic_id',id);
  const {data,error} = await query;
  if(error) throw new AppError(503,'DATABASE_UNAVAILABLE','Clinic information is temporarily unavailable');
  if(id && !data?.length) throw new ResourceNotFoundError();
  return id ? data![0] : data ?? [];
 };
 return {list: async()=>await read('clinics') as unknown[], get:id=>read('clinics',id), settings:id=>read('clinic_settings',id)};
}
