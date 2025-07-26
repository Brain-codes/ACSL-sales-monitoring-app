-- create policy "Allow authenticated inserts to images"
 --  on storage.objects
 --  for insert
 --  to authenticated
-- with check (bucket_id = 'images');


create policy "Allow authenticated select from images"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'images');

create policy "Allow authenticated updates to images"
  on storage.objects
  for update
  to authenticated
  using (bucket_id = 'images')
  with check (bucket_id = 'images');
