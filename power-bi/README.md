# Power BI Report

`Maven_Fuzzy_Factory.pbix` contains the completed Power BI report.

## Refresh requirements

1. Install Power BI Desktop and the MySQL connector required by your Power BI version.
2. Create and load the `maven_fuzzy_factory` MySQL database using the scripts in `../sql/`.
3. Run `05_create_views.sql` and `06_test_views.sql`.
4. Open the `.pbix` file.
5. In Power BI Desktop, open **File > Options and settings > Data source settings**.
6. Update the MySQL server and database connection for your environment.
7. Supply your own MySQL credentials and refresh the report.

Credentials are not included in this repository.

## Report coverage

The report contains visuals covering:

- Campaign order volume and conversion rate
- Unit sales by product and campaign
- Brand campaign performance by device
- Funnel progression by device
- Furthest stage reached by non-converting sessions
- Monthly sales, refunds, revenue, and profitability
- Product profitability and refund performance

