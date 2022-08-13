# AWS Data Migration Service (DMS)

Migration sandbox from a mocked on-premises MySQL database to AWS RDS, for both RDS Aurora and RDS MySQL as target destinations.

<img src=".docs/dms.png" width=700 />

### Crete the source database

Create the EC2 source database infrastructure:

```sh
terraform -chdir='ec2-mysql' init
terraform -chdir='ec2-mysql' apply -auto-approve
```

MySQL will be installed and running via user-data.

Log into the VM using SSM.

Use `sudo mysql` and execute the contexts of file [`prepare-database-.sql`](ec2-mysql/prepare-database-.sql) available in this repository. You can use your favorite SQL editor at this point too.

Once the objects are created, execute the procedure to populate the table.

```sql
CALL populate();
```

The database now have items to be replicated to RDS.

### Migration resources

Test both source and target database endpoints to make sure they're working properly.


Start the migration task