# baseball_sql
SQL scripts for working with the baseball data from retrosheet and baseball-databank, as provided by boxball

The boxball images are documented and available at https://github.com/droher/boxball

I have been working with the 
[Postgres cstore_fdw](https://github.com/droher/boxball#postgres-cstore_fdw-recommended) and 
[MySQL](https://github.com/droher/boxball#mysql) images.  I have created source directories 
with scripts specific to each DBMS.  The column-based postgres is significantly faster than 
the MySql (orders of magnitude with
some scripts).  I recommend using the Postgres rather than MySql.

To get started run the docker command here https://github.com/droher/boxball#postgres-cstore_fdw-recommended
and install a Postgres client (I'm using Portico on OSX).
