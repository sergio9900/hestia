grant execute on function is_group_member(uuid) to authenticated;

grant select, insert, update, delete on table categories to authenticated;

create policy "Allow authenticated users to insert categories"
    on categories
    for all
    to authenticated
    using ( is_group_member(group_id) )
    with check ( is_group_member(group_id) );
