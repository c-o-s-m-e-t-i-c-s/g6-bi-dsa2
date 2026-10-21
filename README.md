<div align="center">

# Healthcare Industry

Business Intelligence

3DSA2 | Group 6

Members: <br>
Cosme, Marcelo B. <br>
Labnas, Elizabeth C. <br>
San Pedro, Micah Andrea S. <br>
Zantua, Karmen N. <br>


</div>

## **Executive Summary**

The proposed business intelligence solution aims to streamline fragmented and inconsistent healthcare data by integrating an interactive BI dashboard with a centralized database, allowing for an efficient and data-driven decision making process for the hospital management and operations. 

Currently, the hospital management has difficulty analyzing the performance of the hospital due to numerous factors such as fragmented data infrastructure, inconsistent data records, duplicate and incomplete patient records, and a lack of a centralized data repository. This leads to a reduction in hospital operational efficiency that further compounds into issues such as long appointment wait times, medication shortages and excess inventory, and inefficient appointment and staff scheduling conflicts.

The proposed BI dashboard's objective is to provide the hospital management with improved real-time operational visibility, continuous monitoring of key performance indicators (KPIs), improved reporting of patient admissions, discharges, and flow, identification of operational bottlenecks, improved financial performance monitoring, and historical trend analysis and demand forecasting. Furthermore, a reworked database will also centralize data management, streamline appointment booking, reduce data redundancy, standardize data formats, and ensure reliable data backup and recovery.

## **Data Source**

## **Problem Statement**

## **Metrics (KPIs, threshold)**

## **Website**

## **Sample Dashboard**

## **Solution Architecture**

## **How to Run**

### import data.py

Note: Importing the healthcare dataset files requires approximately 18 GB of available storage space. Ensure sufficient disk space is available before running the import script.

1. **Set healthcare dataset directory**

Open the VSCode terminal and run:

```python
$env:DATA_DIR = "C:\Users\User\replace-data-set-here-location"

python "C:\Users\User\g6-bi-dsa2\src\import data.py"
```

Replace the example dataset with the location of your healthcare dataset folder. The dataset should ideally remain outside the Git repository

2. **Configure import parameters**

In src/import data.py, configure the following parameters before running the script:

```python
    CHECK_ONLY = True                      # change to False to actually load
    CREATE_TABLES = False            # run once, then set back to False
    ONLY = None                            # e.g. ["STG_EHP__ALGY"] to test one table
```
- ``CHECK_ONLY``: Set to True to check dataset files without loading. Set to False to import dataset files
- ``CREATE_TABLES``: Set to True when creating the MySQL tables for the first time. Set back to false afterward
- ``ONLY``: Set to None to process all applicable tables, or specify a specific list of table names

