Class PivotToJupyter.CustomKPIAction Extends %DeepSee.KPI
{

XData KPI [ XMLNamespace = "http://www.intersystems.com/deepsee/kpi" ]
{
<kpi
xmlns="http://www.intersystems.com/deepsee/kpi"
 name="PivotToJupyter Custom Action">

<action name="PivotToJupyter"/>
</kpi>
}

ClassMethod %OnDashboardAction(pAction As %String, pContext As %ZEN.proxyObject) As %Status
{
    set tSC = $$$OK
    try {
	    if (pAction="PivotToJupyter") {
            // Convert selected context to a new table
            Set tCurrFilterSpec = $P(pContext.currFilterSpec," ",2,*)
            If tCurrFilterSpec="" {
                // Check filters to see if no context is selected but filters are applied
                Set tRS=##class(%DeepSee.ResultSet).%New()
                Do tRS.%PrepareMDX(pContext.mdx)
                Do tRS.%GetFiltersForCellRange(.tFilters,0,0,,,,1,1)
                set f=$O(tFilters(""))
                While f'="" {
                    Set tCurrFilterSpec=tCurrFilterSpec_"%FILTER "_tFilters(f)
                    set f=$O(tFilters(f))
                }
                Set tCurrFilterSpec = $P(tCurrFilterSpec," ",2,*)
            }
            set ^PivotToJupyter("last-filterspec") = tCurrFilterSpec
            Set tNewTableName = "PivotToJupyter."_pContext.cubeName_$translate($zdt($h,8)," :","")
            Set tSC = ##class(%DeepSee.ResultSet).%CreateTable(pContext.cubeName,tNewTableName,tCurrFilterSpec)
            quit:$$$ISERR(tSC)

            // Create a new Jupyter notebook based on new table
            Do ..GenerateNotebook(tNewTableName, tCurrFilterSpec)

            // Navigate to new Jupyter notebook
            set host = $g(^PivotToJupyter("jupyter-host"),"localhost"),
                port = $g(^PivotToJupyter("jupyter-port"),8888)
            Set pContext.command = "newWindow:http://"_host_":"_port_"/notebooks/"_tNewTableName_".ipynb"
        }
	} catch (ex) {
        set tSC = ex.AsStatus()
    }
    set:$$$ISERR(tSC) ^PivotToJupyter("last-error") = tSC
	quit tSC
}

ClassMethod UpdateActionClass(pCube = "HOLEFOODS")
{
    // Update actionClass for HoleFoods cube
    Set tSC=$$$OK
    Set tActionClass="PivotToJupyter.CustomKPIAction"

    Set tCubeClass=##class(%DeepSee.Utils).%GetCubeClass(pCube)

    Set tModel=##class(%DeepSee.Utils).%GetModel(pCube)
    Set tModel.actionClass=tActionClass

    Set tSC=##class(%DeepSee.Utils).%SaveCubeDefinition(tCubeClass,,tModel.description,tModel)
    Quit:$$$ISERR(tSC) tSC
    Set tSC=$System.OBJ.Compile(tCubeClass,"fck /displayerror=0 /displaylog=0")
    Quit:$$$ISERR(tSC) tSC

    Quit tSC
}

ClassMethod GenerateNotebook(tNewTableName, tCurrFilterSpec) [ Language = python ]
{
    import nbformat as nbf
    import iris
    from pathlib import Path
    
    # Create a new notebook
    nb = nbf.v4.new_notebook()
    
    nb["metadata"]["kernelspec"] = {
        "name": "python3",
        "display_name": "Python 3",
        "language": "python"
    }
    
    # Add cells
    nb.cells = [
        nbf.v4.new_markdown_cell("# InterSystems IRIS BI - Dynamic Notebook Example\n"
                                "This notebook connects to an IRIS instance and queries the `"+tNewTableName+"` table."),
        nbf.v4.new_markdown_cell("## Prerequisites\n"
                                "- Install required packages:\n"
                                "```bash\n"
                                "pip install pyodbc pandas matplotlib seaborn sqlalchemy-iris\n"
                                "```\n"
                                "- Set up an ODBC DSN (e.g., `myirisdsn`) that connects to your IRIS instance."),
        nbf.v4.new_code_cell("import pandas as pd\nimport matplotlib.pyplot as plt\nimport seaborn as sns\nfrom sqlalchemy import create_engine\nfrom sqlalchemy.pool import NullPool"),
    
        nbf.v4.new_code_cell("# Set up the connection -- change these as needed! \n"
                            "user = 'SuperUser'\n"
                            "password = 'SYS'\n"
                            "host = 'localhost'\n"
                            "port = 1972\n"
                            "namespace = '"+iris.system.Process.NameSpace()+"'\n"
                            "engine = create_engine(f'iris://{user}:{password}@{host}:{port}/{namespace}', poolclass=NullPool)"),
        nbf.v4.new_code_cell("# Query the "+tNewTableName+" table\n"
                            "query = '''\n"
                            "SELECT * FROM "+tNewTableName+"\n"
                            "'''\n"
                            "with engine.connect() as conn:\n"
                            "    df = pd.read_sql(query, conn)\n"
                            #"engine.dispose()\n"
                            "df.head()"),
        nbf.v4.new_code_cell("# Check for missing values and summary statistics\n"
                            "print(df.isnull().sum())\n"
                            "df.describe()"),
        #nbf.v4.new_code_cell("# Visualize total sales by product\n"
                            #"sales_by_product = df.groupby('Product')['Revenue'].sum().reset_index()\n"
                            #"plt.figure(figsize=(12,6))\n"
                            #"sns.barplot(data=sales_by_product, x='Product', y='Revenue')\n"
                            #"plt.title('Total Sales by Product')\n"
                            #"plt.xticks(rotation=45)\n"
                            #"plt.tight_layout()\n"
                            #"plt.show()"),
        nbf.v4.new_code_cell("# ChatGPT generated code to display a dynamic chart\n"
                            "# Step 1: Get numeric column with highest std dev\n"
                            "excluded_columns = ['ID', '%sourceId']\n"
                            "numeric_df = df.select_dtypes(include='number').drop(columns=excluded_columns, errors='ignore')\n"
                            "use_count = False\n"
                            "if not numeric_df.empty:\n"
                            "    std_devs = numeric_df.std().sort_values(ascending=False)\n"
                            "    if not std_devs.empty:\n"
                            "        target_numeric_col = std_devs.index[0]\n"
                            "    else:\n"
                            "        use_count = True\n"
                            "        target_numeric_col = None\n"
                            "else:\n"
                            "    use_count = True\n"
                            "    target_numeric_col = None\n"

                            "# Step 2: Find best categorical column\n"
                            "cat_cols = df.select_dtypes(include=['string', 'category']).columns\n"
                            "cat_col_stats = [(col, df[col].nunique()) for col in cat_cols]\n"
                            "cat_col_stats.sort(key=lambda x: x[1])  # Sort by number of unique values\n"

                            "target_cat_col = None\n"
                            "max_unique_allowed = 15\n"

                            "# Prefer 5–15 unique values\n"
                            "for col, unique_count in cat_col_stats:\n"
                            "    if 5 <= unique_count <= max_unique_allowed:\n"
                            "        target_cat_col = col\n"
                            "        break\n"

                            "# If no 5–15, try the lowest >15 (and plan to consolidate)\n"
                            "if not target_cat_col:\n"
                            "    for col, unique_count in cat_col_stats:\n"
                            "        if unique_count > max_unique_allowed:\n"
                            "            target_cat_col = col\n"
                            "            # Consolidate here\n"
                            "            top_n = max_unique_allowed\n"
                            "            top_vals = df[col].value_counts().nlargest(top_n).index\n"
                            "            df[col + '_grouped'] = df[col].where(df[col].isin(top_vals), other='Other')\n"
                            "            target_cat_col = col + '_grouped'\n"
                            "            break\n"

                            "# If nothing yet, pick the lowest unique count >= 2 (don't want just one group)\n"
                            "if not target_cat_col:\n"
                            "    for col, unique_count in cat_col_stats:\n"
                            "        if unique_count >= 2:\n"
                            "            target_cat_col = col\n"
                            "            break\n"

                            "# Step 3: Plot\n"
                            "if target_cat_col:\n"
                            "    plt.figure(figsize=(12,6))\n"
                            "    if use_count:\n"
                            "        sns.countplot(data=df, x=target_cat_col, order=df[target_cat_col].value_counts().index)\n"
                            "        plt.title(f'Count of Records by {target_cat_col}')\n"
                            "    else:\n"
                            "        sns.barplot(data=df, x=target_cat_col, y=target_numeric_col, estimator='mean')\n"
                            "        plt.title(f'Mean {target_numeric_col} by {target_cat_col}')\n"
                            "    plt.xticks(rotation=75)\n"
                            "    plt.tight_layout()\n"
                            "    plt.show()\n"
                            "else:\n"
                            "    print('No suitable categorical column found.')\n")
    ]

    if tCurrFilterSpec:
        specArray = tCurrFilterSpec.split(" %FILTER ")

        specMessageArray = ["\n\nThe following context was used:"]
        specMessageArray.extend([f"- {s}" for s in specArray])
        specMessage = "\n".join(specMessageArray)

        nb.cells[0]['source'] += specMessage

    # Save to local directory
    notebookDir = Path("notebooks")
    notebookDir.mkdir(parents=True, exist_ok=True)
    notebook_path = Path("notebooks",tNewTableName+".ipynb").resolve()
    with open(notebook_path, "w", encoding="utf-8") as f:
        nbf.write(nb, f)

    return
}

}
