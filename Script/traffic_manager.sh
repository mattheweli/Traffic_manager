#!/bin/sh
# ==============================================================================
# TRAFFIC MANAGER v1.0.10 - Timezone Fix Only
# Features:
# - FIX: Forces system Timezone to prevent 1-hour offset in hourly stats.
# - REST: Identical to v1.0.9 (Summary Layout Fix).
# ==============================================================================

PATH=/opt/bin:/opt/sbin:/bin:/sbin:/usr/bin:/usr/sbin

# --- FORCE TIMEZONE ---
if [ -f /etc/TZ ]; then 
    export TZ=$(cat /etc/TZ)
elif [ -f /opt/etc/TZ ]; then 
    export TZ=$(cat /opt/etc/TZ)
fi

VNSTAT="/opt/bin/vnstat"
BASE_DIR="/opt/var/www"
OUTDIR="${2:-$BASE_DIR/vnstat}"
IFACE="${1:-}"

# --- 1. CONFIGURATION & CHECKS ---
if [ -z "$IFACE" ]; then
  IFACE=$($VNSTAT --dblist 2>/dev/null | grep -v "Database" | grep -v "^$" | head -n 1 | awk '{print $1}')
fi
[ -z "$IFACE" ] && { echo "ERROR: No interface found."; exit 1; }

mkdir -p "$OUTDIR"
HTMLFILE="${OUTDIR}/${IFACE}-vnstat.html"
DATAFILE="${OUTDIR}/vnstat_data.js"

# --- 2. UPDATE DB & EXPORT JSON ---
$VNSTAT -i "$IFACE" -u >/dev/null 2>&1

echo "Exporting traffic data for $IFACE..."
JSON_DATA=$($VNSTAT -i "$IFACE" --json)

if [ -n "$JSON_DATA" ]; then
    echo "window.TRAFFIC_RAW = $JSON_DATA;" > "$DATAFILE"
else
    echo "window.TRAFFIC_RAW = { error: true };" > "$DATAFILE"
fi

# --- 3. GENERATE HTML ---
if [ ! -f "$HTMLFILE" ] || [ "$1" = "force" ]; then
    echo "Generating HTML Dashboard..."
    
cat <<'EOF' > "$HTMLFILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Keenetic Traffic Analyzer</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>📊</text></svg>">
    <script src="../ping/chart.js"></script> 
    
    <style>
        :root { 
            --bg: #f4f7f6; --card: #ffffff; --text: #333; --muted: #6c757d; 
            --border: #e9ecef; --blue: #0d6efd; --green: #198754; --red: #dc3545;
            --purple: #6f42c1; --orange: #fd7e14;
            --bar-bg: #e9ecef; --est-color: #666;
            --shadow: rgba(0,0,0,0.03); 
        }
        @media (prefers-color-scheme: dark) { 
            :root { --bg: #121212; --card: #1e1e1e; --text: #e0e0e0; --muted: #a0a0a0; --border: #2c2c2c; --shadow: rgba(0,0,0,0.5); --bar-bg: #333; --est-color: #aaa; } 
        }
        
        body { font-family: -apple-system, sans-serif; background: var(--bg); color: var(--text); padding: 20px; max-width: 1200px; margin: 0 auto; }
        
        /* HEADER */
        .status-bar { 
            display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; 
            background: var(--card); padding: 15px 20px; border-radius: 8px; 
            border: 1px solid var(--border); margin-bottom: 25px; gap: 15px;
        }
        .header-title { margin: 0; font-weight: 700; display: flex; align-items: center; gap: 15px; font-size: 1.5rem; }
        .btn-home { text-decoration: none; font-size: 22px; border-right: 1px solid var(--border); padding-right: 15px; transition: transform 0.2s; }
        .btn-home:hover { transform: scale(1.1); }
        
        .status-controls { display: flex; align-items: center; gap: 15px; }
        
        .btn-refresh { background-color: var(--blue); color: #fff; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; text-decoration: none; font-size: 13px; font-weight: 600;}

        /* SUMMARY - COMPACT LAYOUT */
        .summary-card { background: var(--card); border: 1px solid var(--border); border-radius: 8px; box-shadow: 0 2px 4px var(--shadow); margin-bottom: 25px; display: flex; flex-wrap: wrap; overflow: hidden; }
        
        /* Reduced min-width to 150px to fit 5 columns in ~800px width */
        .summary-col { flex: 1; min-width: 150px; padding: 15px; border-right: 1px solid var(--border); display: flex; flex-direction: column; align-items: center; justify-content: flex-start; position: relative; }
        .summary-col:last-child { border-right: none; background: rgba(128,128,128,0.02); }
        
        .sum-title { font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--muted); margin-bottom: 12px; width: 100%; text-align: center; border-bottom: 1px solid var(--border); padding-bottom: 5px; }
        .sum-body { display: flex; gap: 10px; align-items: center; width: 100%; justify-content: center; }
        .sum-chart { width: 70px; height: 70px; position: relative; flex-shrink: 0; }
        .sum-data { display: flex; flex-direction: column; gap: 3px; font-size: 12px; min-width: 85px; }
        .stat-row { display: flex; justify-content: space-between; }
        .stat-est { color: var(--est-color); font-weight: 600; font-style: italic; font-size: 11px; margin-top: 4px; display: flex; justify-content: space-between; border-top: 1px dashed var(--border); padding-top: 2px; }
        
        .c-rx { color: var(--blue); } .c-tx { color: var(--green); } 
        .c-rx-old { color: var(--purple); } .c-tx-old { color: var(--orange); }
        .c-tot { font-weight: bold; }

        /* TABLES & CARDS */
        .card { background: var(--card); border-radius: 8px; border: 1px solid var(--border); margin-bottom: 25px; box-shadow: 0 2px 4px var(--shadow); display: flex; flex-direction: column; }
        .card-head { background: var(--border); padding: 8px 15px; font-size: 12px; font-weight: 700; text-transform: uppercase; color: var(--muted); letter-spacing: 1px; }
        
        .table-responsive { width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; }
        
        table { width: 100%; border-collapse: collapse; font-size: 12px; font-family: monospace; table-layout: fixed; min-width: 500px; }
        th { text-align: right; padding: 8px 10px; color: var(--muted); border-bottom: 2px solid var(--border); font-weight: 700; white-space: nowrap; }
        
        th:first-child { text-align: left; width: 95px; }
        th.th-graph { text-align: left; width: 25%; } 
        
        td { padding: 6px 10px; border-bottom: 1px solid var(--border); text-align: right; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        td:first-child { text-align: left; font-weight: 600; color: var(--text); }
        
        .bar-container { width: 100%; height: 14px; background: var(--bar-bg); border-radius: 3px; display: flex; overflow: hidden; }
        .bar-rx { height: 100%; background: var(--blue); opacity: 0.8; }
        .bar-tx { height: 100%; background: var(--green); opacity: 0.8; }
        
        .row-est td { color: var(--est-color); font-style: italic; background: rgba(128,128,128,0.05); }
        .row-est .bar-rx { opacity: 0.5; } .row-est .bar-tx { opacity: 0.5; }

        .loading { text-align: center; padding: 50px; color: var(--muted); }

        @media(max-width: 900px) { 
            .summary-col { border-right: none; border-bottom: 1px solid var(--border); } 
            .summary-col:last-child { border-bottom: none; } 
        }
        
        @media(max-width: 768px) {
            body { padding: 10px; }
            .status-bar { flex-direction: column; text-align: center; } 
            .header-title { font-size: 1.3rem; justify-content: center; }
            .status-controls { width: 100%; justify-content: center; }
            
            th, td { padding: 6px 4px; font-size: 11px; }
            th:first-child { width: 85px; }
            th.th-graph { width: 20%; }
            .summary-col { min-width: 100%; }
        }
    </style>
</head>
<body>

    <div class="status-bar">
        <h2 class="header-title">
            <a href="../index.html" class="btn-home" title="Back to Dashboard">🏠</a>
            <span>📊 Keenetic Traffic Analyzer</span>
        </h2>
        <div class="status-controls">
            <span id="iface_name" style="font-weight:bold; color:var(--blue); font-size:1.1em">-</span>
            <a href="javascript:location.reload()" class="btn-refresh">Refresh</a>
        </div>
    </div>

    <div id="loading" class="loading">Loading Data...</div>

    <div id="content" style="display:none">
        
        <div class="summary-card">
            <div class="summary-col">
                <div class="sum-title">Today</div>
                <div class="sum-body">
                    <div class="sum-data">
                        <div class="stat-row"><span>Rx:</span> <span class="c-rx" id="s_td_rx">-</span></div>
                        <div class="stat-row"><span>Tx:</span> <span class="c-tx" id="s_td_tx">-</span></div>
                        <div class="stat-row"><span>Tot:</span> <span class="c-tot" id="s_td_tot">-</span></div>
                        <div class="stat-est"><span>Est:</span> <span id="s_td_est">-</span></div>
                    </div>
                    <div class="sum-chart"><canvas id="pie_today"></canvas></div>
                </div>
            </div>
            <div class="summary-col">
                <div class="sum-title">Yesterday</div>
                <div class="sum-body">
                    <div class="sum-data">
                        <div class="stat-row"><span>Rx:</span> <span class="c-rx-old" id="s_yd_rx">-</span></div>
                        <div class="stat-row"><span>Tx:</span> <span class="c-tx-old" id="s_yd_tx">-</span></div>
                        <div class="stat-row"><span>Tot:</span> <span class="c-tot" id="s_yd_tot">-</span></div>
                    </div>
                    <div class="sum-chart"><canvas id="pie_yesterday"></canvas></div>
                </div>
            </div>
            <div class="summary-col">
                <div class="sum-title" id="lbl_tm">Month</div>
                <div class="sum-body">
                    <div class="sum-data">
                        <div class="stat-row"><span>Rx:</span> <span class="c-rx" id="s_tm_rx">-</span></div>
                        <div class="stat-row"><span>Tx:</span> <span class="c-tx" id="s_tm_tx">-</span></div>
                        <div class="stat-row"><span>Tot:</span> <span class="c-tot" id="s_tm_tot">-</span></div>
                        <div class="stat-est"><span>Est:</span> <span id="s_tm_est">-</span></div>
                    </div>
                    <div class="sum-chart"><canvas id="pie_month"></canvas></div>
                </div>
            </div>
            <div class="summary-col">
                <div class="sum-title" id="lbl_lm">Last Month</div>
                <div class="sum-body">
                    <div class="sum-data">
                        <div class="stat-row"><span>Rx:</span> <span class="c-rx-old" id="s_lm_rx">-</span></div>
                        <div class="stat-row"><span>Tx:</span> <span class="c-tx-old" id="s_lm_tx">-</span></div>
                        <div class="stat-row"><span>Tot:</span> <span class="c-tot" id="s_lm_tot">-</span></div>
                    </div>
                    <div class="sum-chart"><canvas id="pie_lmonth"></canvas></div>
                </div>
            </div>
            <div class="summary-col">
                <div class="sum-title">All Time</div>
                <div class="sum-body">
                    <div class="sum-data">
                        <div class="stat-row"><span>Rx:</span> <span class="c-rx" id="s_all_rx">-</span></div>
                        <div class="stat-row"><span>Tx:</span> <span class="c-tx" id="s_all_tx">-</span></div>
                        <div class="stat-row"><span>Tot:</span> <span class="c-tot" id="s_all_tot">-</span></div>
                        <div style="margin-top:10px; font-size:10px; color:var(--muted); text-align:right;">Since:<br><span id="s_created">-</span></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-head">Last 24 Hours</div>
            <div class="table-responsive">
                <table id="tab_hour">
                    <thead><tr><th>Hour</th><th>Rx</th><th>Tx</th><th>Total</th><th>Avg</th><th class="th-graph">Graph</th></tr></thead>
                    <tbody></tbody>
                </table>
            </div>
        </div>

        <div class="card">
            <div class="card-head">Daily History</div>
            <div class="table-responsive">
                <table id="tab_day">
                    <thead><tr><th>Date</th><th>Rx</th><th>Tx</th><th>Total</th><th>Avg</th><th class="th-graph">Graph</th></tr></thead>
                    <tbody></tbody>
                </table>
            </div>
        </div>

        <div class="card">
            <div class="card-head">Monthly History</div>
            <div class="table-responsive">
                <table id="tab_mon">
                    <thead><tr><th>Month</th><th>Rx</th><th>Tx</th><th>Total</th><th>Avg</th><th class="th-graph">Graph</th></tr></thead>
                    <tbody></tbody>
                </table>
            </div>
        </div>

        <div class="card">
            <div class="card-head">Yearly History</div>
            <div class="table-responsive">
                <table id="tab_year">
                    <thead><tr><th>Year</th><th>Rx</th><th>Tx</th><th>Total</th><th>Avg</th><th class="th-graph">Graph</th></tr></thead>
                    <tbody></tbody>
                </table>
            </div>
        </div>

        <div class="card">
            <div class="card-head">📊 Top 10 Days</div>
            <div class="table-responsive">
                <table id="tab_top">
                    <thead><tr><th>Date</th><th>Rx</th><th>Tx</th><th>Total</th><th>Avg Rate</th><th class="th-graph">Graph</th></tr></thead>
                    <tbody></tbody>
                </table>
            </div>
        </div>

    </div>

    <script>
        document.write('<script src="vnstat_data.js?v=' + Date.now() + '"><\/script>');
    </script>
    
    <script>
        // PRESENT COLORS (Blue / Green)
        const COL_RX = 'rgba(13, 110, 253, 0.85)';
        const COL_TX = 'rgba(25, 135, 84, 0.85)';
        const COL_RX_A = 'rgba(13, 110, 253, 0.15)'; // Ghost
        const COL_TX_A = 'rgba(25, 135, 84, 0.15)';

        // PAST COLORS (Purple / Orange)
        const COL_RX_OLD = 'rgba(111, 66, 193, 0.85)';
        const COL_TX_OLD = 'rgba(253, 126, 20, 0.85)';

        function fmt(bytes) {
            if (!bytes) return '0 B';
            const k = 1024; const sizes = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }

        function fmtBits(bps) {
            if (bps < 1000) return bps.toFixed(2) + " bit/s";
            const k = 1000; const sizes = ['kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'];
            const i = Math.floor(Math.log(bps) / Math.log(k));
            return parseFloat((bps / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i-1];
        }

        function pDate(d, type) {
            if(!d) return "-";
            const h = (d.time && d.time.hour !== undefined) ? d.time.hour : d.hour;
            const D = (d.date) ? d.date : d; 
            const mNames = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
            
            if(type=='h') return `${String(h).padStart(2,'0')}:00`;
            if(type=='d') return `${String(D.day).padStart(2,'0')}/${String(D.month).padStart(2,'0')}`;
            if(type=='m') return `${mNames[D.month]} '${String(D.year).substr(2)}`;
            if(type=='mn') return mNames[D.month];
            if(type=='y') return D.year;
            return `${String(D.day).padStart(2,'0')}/${String(D.month).padStart(2,'0')}/${D.year}`;
        }

        function calcRate(bytes, dObj, type, dbDate) {
            let secs = 1;
            const D = (dObj.date) ? dObj.date : dObj;
            
            const isCurrent = (
                (type=='d' && D.day == dbDate.getDate() && D.month == dbDate.getMonth()+1 && D.year == dbDate.getFullYear()) ||
                (type=='m' && D.month == dbDate.getMonth()+1 && D.year == dbDate.getFullYear()) ||
                (type=='y' && D.year == dbDate.getFullYear())
            );

            if(isCurrent) {
                if(type=='d') {
                    secs = (dbDate.getHours()*3600) + (dbDate.getMinutes()*60) + dbDate.getSeconds();
                } else if(type=='m') {
                    secs = ((dbDate.getDate()-1)*86400) + (dbDate.getHours()*3600) + (dbDate.getMinutes()*60);
                } else if(type=='y') {
                    const start = new Date(dbDate.getFullYear(), 0, 1);
                    secs = (dbDate - start) / 1000;
                }
                if(secs < 60) secs = 60; 
            } else {
                if(type=='h') secs = 3600;
                else if(type=='d') secs = 86400;
                else if(type=='m') secs = 86400 * 30; 
                else if(type=='y') secs = 86400 * 365;
            }
            return fmtBits((bytes * 8) / secs);
        }

        // FIXED YEAR ESTIMATE LOGIC
        function getEst(current, type, dbDate) {
            let totalSecs = 0; let passedSecs = 0;
            const D = (current.date) ? current.date : current;

            // Strict year check
            if (type === 'y' && D.year !== dbDate.getFullYear()) return null;
            if (type === 'm' && (D.month !== dbDate.getMonth()+1 || D.year !== dbDate.getFullYear())) return null;
            if (type === 'd' && (D.day !== dbDate.getDate() || D.month !== dbDate.getMonth()+1)) return null;

            if (type === 'd') {
                totalSecs = 86400;
                passedSecs = (dbDate.getHours() * 3600) + (dbDate.getMinutes() * 60) + dbDate.getSeconds();
            } else if (type === 'm') {
                const daysInMonth = new Date(dbDate.getFullYear(), dbDate.getMonth()+1, 0).getDate();
                totalSecs = daysInMonth * 86400;
                passedSecs = ((dbDate.getDate()-1) * 86400) + (dbDate.getHours() * 3600) + (dbDate.getMinutes() * 60);
            } else if (type === 'y') {
                const startOfYear = new Date(dbDate.getFullYear(), 0, 1);
                const endOfYear = new Date(dbDate.getFullYear() + 1, 0, 1);
                totalSecs = (endOfYear - startOfYear) / 1000;
                passedSecs = (dbDate - startOfYear) / 1000;
            } else return null;

            if(passedSecs <= 0) return null;
            const factor = totalSecs / passedSecs;
            return { 
                rx: (current.rx * factor) - current.rx, 
                tx: (current.tx * factor) - current.tx,
                date: "estimated"
            };
        }

        window.onload = function() {
            if(typeof window.TRAFFIC_RAW === 'undefined' || window.TRAFFIC_RAW.error) {
                document.getElementById('loading').innerText = "Error: No Data."; return;
            }
            const data = window.TRAFFIC_RAW;
            const iface = data.interfaces[0];
            const tr = iface.traffic;

            let dbTime = new Date(); 
            if(iface.updated && iface.updated.date) {
                const u = iface.updated;
                dbTime = new Date(u.date.year, u.date.month - 1, u.date.day, u.time.hour, u.time.minute);
            }

            document.getElementById('loading').style.display = 'none';
            document.getElementById('content').style.display = 'block';
            document.getElementById('iface_name').innerText = iface.name;
            if(iface.created && iface.created.date) document.getElementById('s_created').innerText = pDate(iface.created.date, 'f');

            // --- 1. SUMMARY ---
            const getLast = (arr, offset) => arr[arr.length - 1 - offset] || {rx:0, tx:0};
            
            const today = getLast(tr.day, 0);
            const yest = getLast(tr.day, 1);
            const tmon = getLast(tr.month, 0);
            const lmon = getLast(tr.month, 1);
            const total = tr.total;

            const fillSum = (pfx, d) => {
                document.getElementById(pfx+'_rx').innerText = fmt(d.rx);
                document.getElementById(pfx+'_tx').innerText = fmt(d.tx);
                document.getElementById(pfx+'_tot').innerText = fmt(d.rx+d.tx);
            };
            fillSum('s_td', today); fillSum('s_yd', yest);
            fillSum('s_tm', tmon);  fillSum('s_lm', lmon);
            fillSum('s_all', total);
            
            // FIXED: Passing 'm' format (month+year) for summary headers
            if(tmon.date) document.getElementById('lbl_tm').innerText = pDate(tmon.date, 'm');
            if(lmon.date) document.getElementById('lbl_lm').innerText = pDate(lmon.date, 'm');

            // Estimates
            const remDay = getEst(today, 'd', dbTime);
            const remMon = getEst(tmon, 'm', dbTime);
            
            if(remDay) document.getElementById('s_td_est').innerText = fmt( (today.rx+remDay.rx) + (today.tx+remDay.tx) );
            if(remMon) document.getElementById('s_tm_est').innerText = fmt( (tmon.rx+remMon.rx) + (tmon.tx+remMon.tx) );

            const mkPie = (id, cur, rem, isPast) => {
                let colRx = isPast ? COL_RX_OLD : COL_RX;
                let colTx = isPast ? COL_TX_OLD : COL_TX;
                
                let d = [cur.rx, cur.tx];
                let c = [colRx, colTx];
                
                if(rem) {
                    d.push(rem.rx, rem.tx);
                    c.push(COL_RX_A, COL_TX_A);
                }
                new Chart(document.getElementById(id), {
                    type: 'doughnut',
                    data: { labels:[], datasets:[{data:d, backgroundColor:c, borderWidth:0}] },
                    options: { 
                        cutout:'25%', 
                        layout: { padding: 5 }, 
                        plugins:{tooltip:{enabled:false}, legend:{display:false}}, 
                        maintainAspectRatio:false 
                    }
                });
            };
            
            mkPie('pie_today', today, remDay, false); 
            mkPie('pie_yesterday', yest, null, true);
            mkPie('pie_month', tmon, remMon, false); 
            mkPie('pie_lmonth', lmon, null, true);

            // --- 2. TABLES ---
            const renderTable = (arr, type, tabId, limit, showEst, sortDesc) => {
                let data = arr.slice();
                if(sortDesc) {
                   data.sort((a,b)=>(b.rx+b.tx)-(a.rx+a.tx));
                   data = data.slice(0, limit);
                } else {
                   data = data.slice(-limit).reverse();
                }
                
                const tbody = document.querySelector('#'+tabId+' tbody');
                let maxVal = 0;
                data.forEach(d => { if((d.rx+d.tx) > maxVal) maxVal = (d.rx+d.tx); });
                
                if(showEst && !sortDesc && data.length > 0) {
                    const estRem = getEst(data[0], type, dbTime); 
                    if(estRem) {
                        const estTotRx = data[0].rx + estRem.rx;
                        const estTotTx = data[0].tx + estRem.tx;
                        if((estTotRx+estTotTx) > maxVal) maxVal = (estTotRx+estTotTx);
                        data.unshift({ rx: estTotRx, tx: estTotTx, date: "estimated" });
                    }
                }

                data.forEach(x => {
                    const tot = x.rx + x.tx;
                    const pctRx = (x.rx / maxVal) * 100;
                    const pctTx = (x.tx / maxVal) * 100;
                    const isEst = (x.date === "estimated");
                    
                    const r = document.createElement('tr');
                    if(isEst) r.classList.add('row-est');
                    
                    let dateStr = isEst ? "estimated" : pDate(x, type);
                    
                    r.innerHTML = `
                        <td>${dateStr}</td>
                        <td class="c-rx">${fmt(x.rx)}</td>
                        <td class="c-tx">${fmt(x.tx)}</td>
                        <td class="c-tot">${fmt(tot)}</td>
                        <td>${isEst ? '-' : calcRate(tot, x, type, dbTime)}</td>
                        <td class="td-graph">
                            <div class="bar-container">
                                <div class="bar-rx" style="width:${pctRx}%"></div>
                                <div class="bar-tx" style="width:${pctTx}%"></div>
                            </div>
                        </td>
                    `;
                    tbody.appendChild(r);
                });
            };

            renderTable(tr.hour, 'h', 'tab_hour', 24, false, false);
            renderTable(tr.day, 'd', 'tab_day', 30, true, false);
            renderTable(tr.month, 'm', 'tab_mon', 12, true, false);
            renderTable(tr.year, 'y', 'tab_year', 10, true, false);
            renderTable(tr.day, 'd', 'tab_top', 10, false, true);
        };
    </script>
</body>
</html>
EOF
fi
