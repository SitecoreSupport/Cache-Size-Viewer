<%@ Page Language="C#" AutoEventWireup="true" Debug="false" %>

<%@ Import Namespace="Sitecore.Caching" %>
<%@ Import Namespace="Sitecore.Configuration" %>
<%@ Import Namespace="System.Linq" %>
<!DOCTYPE html>
<html>
<head>
    <title>Cache Size Viewer</title>
    <meta content="C#" name="CODE_LANGUAGE">

    <style type="text/css">
        body {
            font-family: 'Open Sans', sans-serif;
        }

        div {
            padding: 20px;
        }

        table {
            border-collapse: collapse;
        }

        table, th, td {
            border: 1px solid black;
            padding: 5px;
        }

        th {
            background-color: #F5F5F5;
        }

        td.AlignRight {
            text-align: right;
        }

        td.MaxSize {
            color: lightgray;
        }

        td.CacheUtilizationHigh {
        }

        td.CacheUtilizationLow {
            color: lightgray;
        }
    </style>

    <script runat="server">
        public class CellEntry
        {
            public string Value { get; set; }
            public string CssClass { get; set; }

            public static implicit operator CellEntry(string param)
            {
                return new CellEntry(param);
            }

            public CellEntry(string value, string cssClass = "")
            {
                Value = value;
                CssClass = cssClass;
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            // Render Header
            string pageVersion = "1.0.0";
            string pageName = "Sitecore Cache Size Viewer";
            Header.InnerHtml = string.Format("<h2>{0}</h2><h6>Version:&nbsp;{1}</h6>", pageName, pageVersion);

            // Render Statistics
            CacheStatistics statistics = CacheManager.GetStatistics();
            Totals.InnerHtml = RenderOverviewTable(statistics);

            // Render Cache Sizes
            ICacheInfo[] allCaches = CacheManager.GetAllCaches();
            Caches.InnerHtml = RenderCacheSizeTable(allCaches);
        }

        private string RenderOverviewTable(CacheStatistics statistics)
        {
            List<List<CellEntry>> tableData = new List<List<CellEntry>>();

            string separator = "&nbsp";

            List<CellEntry> header = new List<CellEntry>(new CellEntry[] { "Metric", "Value" });
            tableData.Add(header);

            tableData.Add(new List<CellEntry> { "Total Entries Count", statistics.TotalCount.ToString() });

            tableData.Add(new List<CellEntry>{ "Total Size",statistics.TotalSize.ToString() + separator +
                string.Format("({0})", FormatSize(statistics.TotalSize, separator))});

            tableData.Add(new List<CellEntry> { "DisableCacheSizeLimits", Settings.Caching.DisableCacheSizeLimits.ToString() });

            string html = RenderTable(tableData);

            return html;
        }

        private string RenderCacheSizeTable(ICacheInfo[] allCaches)
        {
            if (allCaches == null || allCaches.Length <= 0)
            {
                return string.Empty;
            }

            IEnumerable<ICacheInfo> caches = allCaches.OrderBy(c => c.Name);

            List<List<CellEntry>> tableData = new List<List<CellEntry>>();

            List<CellEntry> header = new List<CellEntry>(new CellEntry[]{
                "Name",
                "Count",
                "Size",
                "MaxSize",
                "Utilization,%",
            });

            tableData.Add(header);

            foreach (var cache in caches)
            {
                List<CellEntry> data = new List<CellEntry>();

                string baseCssClassForData = "AlignRight";

                string separator = "&nbsp";

                data.Add(cache.Name);

                CellEntry countEntry = new CellEntry(cache.Count.ToString(), baseCssClassForData);
                data.Add(countEntry);

                CellEntry sizeEntry = new CellEntry(FormatSize(cache.Size, separator), baseCssClassForData);
                data.Add(sizeEntry);

                CellEntry maxSizeEntry = new CellEntry(FormatSize(cache.MaxSize, separator), "MaxSize " + baseCssClassForData);
                data.Add(maxSizeEntry);

                long utilizationLong = GetUtilization(cache.Size, cache.MaxSize);
                string utilizationString = utilizationLong >= 0 ? utilizationLong.ToString() : "n/a";
                string utilizationClass = utilizationLong < 80 ? "CacheUtilizationLow" : "CacheUtilizationHigh";
                CellEntry utilizationEntry = new CellEntry(utilizationString, baseCssClassForData + " " + utilizationClass);
                data.Add(utilizationEntry);

                tableData.Add(data);
            }

            string html = RenderTable(tableData);

            return html;
        }

        private string RenderTable(List<List<CellEntry>> data)
        {
            if (data == null || data.Count < 1)
            {
                return string.Empty;
            }

            int columns = data[0].Count;
            int rows = data.Count;

            // Header 
            StringBuilder html = new StringBuilder();

            html.Append("<table>");
            html.Append("<tr>");

            html.AppendFormat("<th>{0}</th>", "#");

            for (int i = 0; i < columns; i++)
            {
                if (string.IsNullOrWhiteSpace(data[0][i].CssClass))
                {
                    html.AppendFormat("<th>{0}</th>", data[0][i].Value);
                }
                else
                {
                    html.AppendFormat("<th class='{0}'>{1}</th>", data[0][i].CssClass, data[0][i].Value);
                }
            }

            html.Append("</tr>");

            // Body
            if (data.Count < 2)
            {
                html.Append("</table>");

                return html.ToString();
            }

            for (int r = 1; r < rows; r++)
            {
                html.Append("<tr>");

                // Add row number
                html.AppendFormat("<td>{0}</td>", r);

                for (int c = 0; c < columns; c++)
                {
                    if (string.IsNullOrWhiteSpace(data[r][c].CssClass))
                    {
                        html.AppendFormat("<td>{0}</td>", data[r][c].Value);
                    }
                    else
                    {
                        html.AppendFormat("<td class='{0}'>{1}</td>", data[r][c].CssClass, data[r][c].Value);
                    }
                }

                html.Append("</tr>");
            }

            // Footer
            html.Append("</table>");

            return html.ToString();
        }

        private string FormatSize(long size, string separator)
        {
            long num = Math.Abs(size);

            if (num < 1024)
            {
                return string.Format("{0}{1}{2}", size.ToString("#,0"), separator, "B");
            }

            if (num < 1048576)
            {
                return string.Format("{0}{1}{2}", ((double)size / 1024.0).ToString("#,0.#"), separator, "KB");
            }

            if (num < 1073741824)
            {
                return string.Format("{0}{1}{2}", ((double)size / 1048576.0).ToString("#,0.#"), separator, "MB");
            }

            return string.Format("{0}{1}{2}", ((double)size / 1073741824.0).ToString("#,0.#"), separator, "GB");
        }

        private long GetUtilization(long cacheSize, long cacheMaxSize)
        {
            if (cacheMaxSize <= 0 || cacheSize < 0)
            {
                return -1;
            }

            long utilization = 100 * cacheSize / cacheMaxSize;

            return utilization;
        }
    </script>

    <link rel="shortcut icon" type="image/png" href="data:image/png;base64,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">
</head>
<body>

    <div id="Header" runat="server">
    </div>
    <div id="Totals" runat="server">
    </div>
    <div id="Caches" runat="server">
    </div>
</body>
</html>
