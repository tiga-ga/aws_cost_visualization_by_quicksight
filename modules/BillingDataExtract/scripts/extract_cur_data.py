import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.dynamicframe import DynamicFrame
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import traceback
import boto3
from datetime import datetime
from pyspark.sql.functions import col, format_number

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

try:
    # Get job parameters
    args = getResolvedOptions(sys.argv, ['JOB_NAME', 'database_name', 'output_path', 'output_filename'])
    print(f"Job parameters: {args}")

    # Get all tables from the database using Glue catalog API
    try:
        glue_client = boto3.client('glue')
        response = glue_client.get_tables(DatabaseName=args['database_name'])
        tables = [table['Name'] for table in response['TableList']]
        print(f"Found tables: {tables}")
    except Exception as e:
        print(f"Error getting tables from database {args['database_name']}: {str(e)}")
        print(f"Stack trace: {traceback.format_exc()}")
        raise

    # Required fields to extract for analysis
    required_fields = [
        # Cost related
        "lineitem/unblendedcost",
        "lineitem/blendedcost",
        
        # Usage related
        "lineitem/usageamount",
        "lineitem/usageaccountid",
        
        # Resource identification
        "lineitem/resourceid",
        "lineitem/lineitemtype",
        "lineitem/productcode",
        "lineitem/operation",
        
        # Time information
        "lineitem/usagestartdate",
        "lineitem/usageenddate",
        "bill/billingperiodstartdate",
        "bill/billingperiodenddate",
        
        # Product information
        "product/productname",
        "product/region",
    ]

    # Create an empty DataFrame to store all data
    all_data = None
    billing_period_start = None

    # Process each table
    for table_name in tables:
        try:
            print(f"Processing table: {table_name}")
            
            # Read input data
            datasource = glueContext.create_dynamic_frame.from_catalog(
                database=args['database_name'],
                table_name=table_name
            )
            
            # Get billing period from the first record
            if billing_period_start is None:
                df = datasource.toDF()
                if not df.isEmpty():
                    billing_period_start = df.select("bill/billingperiodstartdate").first()[0].split('T')[0]
            
            # Select required fields and convert to DataFrame
            selected_fields = SelectFields.apply(
                frame=datasource,
                paths=required_fields
            ).toDF()
            
            # Union with existing data
            if all_data is None:
                all_data = selected_fields
            else:
                all_data = all_data.union(selected_fields)
                
            print(f"Completed processing table: {table_name}")
        except Exception as e:
            print(f"Error processing table {table_name}: {str(e)}")
            print(f"Stack trace: {traceback.format_exc()}")
            raise

    # Write all data to a single file
    if all_data is not None:
        # Get billing period month
        billing_period_date = datetime.strptime(billing_period_start, '%Y-%m-%d')
        
        # Create output path
        output_path = f"{args['output_path']}/{args['output_filename']}"
        
        # Format numeric columns to prevent scientific notation
        numeric_columns = [
            "lineitem/unblendedcost",
            "lineitem/blendedcost",
            "lineitem/usageamount",
        ]
        
        formatted_df = all_data
        for column in numeric_columns:
            if column in formatted_df.columns:
                formatted_df = formatted_df.withColumn(
                    column,
                    format_number(col(column).cast("decimal(20,10)"), 10)  # 10桁の小数部を持つ形式に変換
                )
        
        # Write to S3
        formatted_df.coalesce(1).write.mode("overwrite").option("compression", "gzip").csv(
            output_path,
            header=True,
            quote='"',
            escape='"',
            sep=',',
            timestampFormat="yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        )
        print(f"Completed writing all data to file: {args['output_filename']}")

    job.commit()
    print("Job completed successfully")

except Exception as e:
    print(f"Job failed with error: {str(e)}")
    print(f"Stack trace: {traceback.format_exc()}")
    raise 