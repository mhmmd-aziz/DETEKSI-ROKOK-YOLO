import React, { useState, useEffect, useRef } from 'react'

const API_BASE = 'http://127.0.0.1:8000'

/* Clean SVG Icon Components (Zero Emojis) */
const IconShieldCheck = () => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    <path d="m9 12 2 2 4-4" />
  </svg>
)

const IconMonitor = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <rect x="2" y="3" width="20" height="14" rx="2" />
    <line x1="8" y1="21" x2="16" y2="21" />
    <line x1="12" y1="17" x2="12" y2="21" />
  </svg>
)

const IconCamera = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z" />
    <circle cx="12" cy="13" r="3" />
  </svg>
)

const IconChartBar = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <line x1="18" y1="20" x2="18" y2="10" />
    <line x1="12" y1="20" x2="12" y2="4" />
    <line x1="6" y1="20" x2="6" y2="14" />
  </svg>
)

const IconPlay = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <polygon points="5 3 19 12 5 21 5 3" />
  </svg>
)

const IconPause = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <rect x="6" y="4" width="4" height="16" />
    <rect x="14" y="4" width="4" height="16" />
  </svg>
)

const IconVideo = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <polygon points="23 7 16 12 23 17 23 7" />
    <rect x="1" y="5" width="15" height="14" rx="2" ry="2" />
  </svg>
)

const IconWebcam = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="10" r="8" />
    <circle cx="12" cy="10" r="3" />
    <path d="M7 22h10" />
    <path d="M12 18v4" />
  </svg>
)

const IconUpload = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="17 8 12 3 7 8" />
    <line x1="12" y1="3" x2="12" y2="15" />
  </svg>
)

const IconTrash = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="3 6 5 6 21 6" />
    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
  </svg>
)

const IconClock = () => (
  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <polyline points="12 6 12 12 16 14" />
  </svg>
)

const IconClose = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.3" strokeLinecap="round" strokeLinejoin="round">
    <line x1="18" y1="6" x2="6" y2="18" />
    <line x1="6" y1="6" x2="18" y2="18" />
  </svg>
)

const IconCheck = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="20 6 9 17 4 12" />
  </svg>
)

const IconSliders = () => (
  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
    <line x1="4" y1="21" x2="4" y2="14" />
    <line x1="4" y1="10" x2="4" y2="3" />
    <line x1="12" y1="21" x2="12" y2="12" />
    <line x1="12" y1="8" x2="12" y2="3" />
    <line x1="20" y1="21" x2="20" y2="16" />
    <line x1="20" y1="12" x2="20" y2="3" />
    <line x1="1" y1="14" x2="7" y2="14" />
    <line x1="9" y1="8" x2="15" y2="8" />
    <line x1="17" y1="16" x2="23" y2="16" />
  </svg>
)

function SvgLineChart({ data, yKey, color = '#059669', unit = '%', minY = 0, maxY = 100, label = '' }) {
  if (!data || data.length === 0) return null
  const width = 520
  const height = 210
  const padL = 42
  const padR = 16
  const padT = 18
  const padB = 28
  const chartW = width - padL - padR
  const chartH = height - padT - padB

  const points = data.map((d, idx) => {
    const x = padL + (idx / Math.max(1, data.length - 1)) * chartW
    const val = Number(d[yKey] || 0)
    const normY = (val - minY) / Math.max(0.0001, maxY - minY)
    const y = padT + chartH - Math.max(0, Math.min(1, normY)) * chartH
    return `${x.toFixed(1)},${y.toFixed(1)}`
  })

  const areaPoints = [
    `${padL},${padT + chartH}`,
    ...points,
    `${padL + chartW},${padT + chartH}`,
  ].join(' ')

  const yTicks = [minY, minY + (maxY - minY) * 0.5, maxY]

  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto' }}>
      <defs>
        <linearGradient id={`grad-${yKey}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.28" />
          <stop offset="100%" stopColor={color} stopOpacity="0.02" />
        </linearGradient>
      </defs>

      {yTicks.map((tick, i) => {
        const y = padT + chartH - ((tick - minY) / (maxY - minY)) * chartH
        return (
          <g key={i}>
            <line x1={padL} y1={y} x2={padL + chartW} y2={y} stroke="#e2eee8" strokeDasharray="4 4" />
            <text x={padL - 8} y={y + 4} textAnchor="end" fontSize="10" fill="#759485" fontWeight="600">
              {tick.toFixed(maxY <= 3 ? 1 : 0)}{unit}
            </text>
          </g>
        )
      })}

      <polygon points={areaPoints} fill={`url(#grad-${yKey})`} />
      <polyline
        fill="none"
        stroke={color}
        strokeWidth="2.6"
        strokeLinecap="round"
        strokeLinejoin="round"
        points={points.join(' ')}
      />

      <text x={padL} y={height - 6} fontSize="10" fill="#759485" fontWeight="600">Epoch 1</text>
      <text x={padL + chartW / 2} y={height - 6} textAnchor="middle" fontSize="10" fill="#476658" fontWeight="700">
        {label}
      </text>
      <text x={padL + chartW} y={height - 6} textAnchor="end" fontSize="10" fill="#759485" fontWeight="600">
        Epoch {data.length}
      </text>
    </svg>
  )
}

export default function App() {
  const [activeTab, setActiveTab] = useState('monitor') // 'monitor' | 'incidents' | 'metrics'
  const [sourceMode, setSourceMode] = useState('cctv_demo') // 'cctv_demo' | 'custom_video' | 'webcam'
  const [confThreshold, setConfThreshold] = useState(0.45)
  const [minConsecutiveFrames, setMinConsecutiveFrames] = useState(12)
  const [twoStage, setTwoStage] = useState(true)
  const [showPersonBox, setShowPersonBox] = useState(true)
  const [paused, setPaused] = useState(false)

  const [status, setStatus] = useState({
    camera_name: 'CAM 01 - CCTV Indoor (Demo)',
    location: 'Gedung Utama Lt. 1 (Kawasan Tanpa Rokok)',
    current_frame: 0,
    total_frames: 240,
    person_count: 5,
    smoker_count: 0,
    cigarette_count: 0,
    consecutive_hits: 0,
    max_confidence: 0.0,
    fps: 28.5,
    inference_ms: 34.2,
    status: 'AMAN',
    device_name: 'NVIDIA GeForce RTX 3050 Laptop GPU',
    total_incidents: 0,
  })
  const [incidents, setIncidents] = useState([])
  const [metrics, setMetrics] = useState(null)
  const [selectedIncident, setSelectedIncident] = useState(null)
  const [streamKey, setStreamKey] = useState(Date.now())
  const fileInputRef = useRef(null)

  const fetchStatus = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/status/`)
      if (res.ok) {
        const data = await res.json()
        setStatus((prev) => ({
          ...prev,
          camera_name: data.camera_name,
          location: data.location,
          current_frame: data.current_frame,
          total_frames: data.total_frames,
          person_count: data.person_count,
          smoker_count: data.smoker_count,
          cigarette_count: data.cigarette_count,
          consecutive_hits: data.consecutive_hits ?? 0,
          max_confidence: data.max_confidence,
          fps: data.fps,
          inference_ms: data.inference_ms,
          status: data.status,
          device_name: data.device_name,
          total_incidents: data.total_incidents,
        }))
      }
    } catch (err) {
      // ignore transient network errors
    }
  }

  const fetchIncidents = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/incidents/?limit=30`)
      if (res.ok) {
        const data = await res.json()
        setIncidents(data.incidents || [])
      }
    } catch (err) {
      // ignore
    }
  }

  const fetchMetrics = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/model-metrics/`)
      if (res.ok) {
        const data = await res.json()
        setMetrics(data)
      }
    } catch (err) {
      // ignore
    }
  }

  useEffect(() => {
    fetch(`${API_BASE}/api/config/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        source_mode: 'cctv_demo',
        conf_threshold: 0.45,
        min_consecutive_frames: 12,
        two_stage: true,
        show_person_box: true,
        paused: false,
      }),
    }).catch(() => {})

    fetchStatus()
    fetchIncidents()
    fetchMetrics()

    const statusTimer = setInterval(fetchStatus, 750)
    const incidentTimer = setInterval(fetchIncidents, 2200)
    return () => {
      clearInterval(statusTimer)
      clearInterval(incidentTimer)
    }
  }, [])

  const handleSwitchMainTab = async (tabName) => {
    setActiveTab(tabName)
    if (tabName !== 'monitor') {
      try {
        await fetch(`${API_BASE}/api/config/`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ stop_stream: true }),
        })
      } catch (err) {
        // ignore
      }
    } else {
      setStreamKey(Date.now())
    }
  }

  const handleSelectSource = async (newSource) => {
    setSourceMode(newSource)
    setPaused(false)
    try {
      await fetch(`${API_BASE}/api/config/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ source_mode: newSource, paused: false }),
      })
    } catch (err) {
      console.error(err)
    }
    setStreamKey(Date.now())
  }

  const handleConfChange = async (newVal) => {
    const val = parseFloat(newVal)
    setConfThreshold(val)
    try {
      await fetch(`${API_BASE}/api/config/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ conf_threshold: val }),
      })
    } catch (err) {
      console.error(err)
    }
  }

  const handleConsecutiveFramesChange = async (newVal) => {
    const val = parseInt(newVal, 10)
    setMinConsecutiveFrames(val)
    try {
      await fetch(`${API_BASE}/api/config/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ min_consecutive_frames: val }),
      })
    } catch (err) {
      console.error(err)
    }
  }

  const handleToggleTwoStage = async (checked) => {
    setTwoStage(checked)
    try {
      await fetch(`${API_BASE}/api/config/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ two_stage: checked }),
      })
    } catch (err) {
      console.error(err)
    }
  }

  const handleTogglePersonBox = async (checked) => {
    setShowPersonBox(checked)
    try {
      await fetch(`${API_BASE}/api/config/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ show_person_box: checked }),
      })
    } catch (err) {
      console.error(err)
    }
  }

  const handleTogglePause = async () => {
    const nextPaused = !paused
    setPaused(nextPaused)
    try {
      await fetch(`${API_BASE}/api/config/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ paused: nextPaused }),
      })
    } catch (err) {
      console.error(err)
    }
  }

  const handleManualCapture = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/capture/`, { method: 'POST' })
      if (res.ok) {
        fetchIncidents()
        fetchStatus()
      }
    } catch (err) {
      console.error(err)
    }
  }

  const handleClearIncidents = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/incidents/`, { method: 'DELETE' })
      if (res.ok) {
        setIncidents([])
        fetchStatus()
      }
    } catch (err) {
      console.error(err)
    }
  }

  const handleVideoUpload = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    const formData = new FormData()
    formData.append('video', file)
    try {
      const res = await fetch(`${API_BASE}/api/upload/`, {
        method: 'POST',
        body: formData,
      })
      if (res.ok) {
        setSourceMode('custom_video')
        setPaused(false)
        setStreamKey(Date.now())
        fetchStatus()
      }
    } catch (err) {
      console.error(err)
    }
  }

  const isAlert = status.status === 'PELANGGARAN MEROKOK'
  const isVerifying = status.status === 'VERIFIKASI'
  const verifyPct = Math.min(100, Math.round((status.consecutive_hits / Math.max(1, minConsecutiveFrames)) * 100))

  return (
    <div className="app-layout">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="brand-box">
          <div className="brand-icon">
            <IconShieldCheck />
          </div>
          <div>
            <div className="brand-title">SmokeGuard AI</div>
            <div className="brand-subtitle">Monitoring KTR • YOLOv8</div>
          </div>
        </div>

        <div className="nav-section-label">Menu Navigasi</div>
        <div className="nav-list">
          <button
            className={`nav-btn ${activeTab === 'monitor' ? 'active' : ''}`}
            onClick={() => handleSwitchMainTab('monitor')}
          >
            <IconMonitor />
            Live Monitoring
          </button>

          <button
            className={`nav-btn ${activeTab === 'incidents' ? 'active' : ''}`}
            onClick={() => handleSwitchMainTab('incidents')}
          >
            <IconCamera size={18} />
            Bukti Pelanggaran
            <span className="nav-badge">{status.total_incidents ?? incidents.length}</span>
          </button>

          <button
            className={`nav-btn ${activeTab === 'metrics' ? 'active' : ''}`}
            onClick={() => handleSwitchMainTab('metrics')}
          >
            <IconChartBar />
            Evaluasi Model TA
          </button>
        </div>

        <div className="sidebar-footer">
          <div className="gpu-chip">
            <span className="pulse-dot" />
            <span>{status.device_name || 'GPU CUDA Active'}</span>
          </div>
          <div className="sidebar-footer-sub">
            Backend: Django 5.2 REST Stream<br />
            Filter Snapshot: Min {minConsecutiveFrames} Frame Konsisten
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <div className="main-area">
        <header className="topbar">
          <div className="topbar-left">
            <h1>
              {activeTab === 'monitor' && 'Dashboard Monitoring Kawasan Tanpa Rokok'}
              {activeTab === 'incidents' && 'Log Bukti Pelanggaran & Snapshot Otomatis'}
              {activeTab === 'metrics' && 'Evaluasi Performa Model YOLOv8 (Tugas Akhir)'}
            </h1>
            <p>{status.camera_name} • {status.location}</p>
          </div>

          <div className="topbar-right">
            <div className={`status-pill ${isAlert ? 'danger' : ''}`}>
              <span className={`pulse-dot ${isAlert ? 'danger' : ''}`} />
              {isAlert
                ? `TERKONFIRMASI MEROKOK (${status.cigarette_count} Titik Rokok)`
                : isVerifying
                ? `VERIFIKASI DETEKSI (${status.consecutive_hits}/${minConsecutiveFrames} Frame)`
                : 'ZONA AMAN • BEBAS ASAP ROKOK'}
            </div>
          </div>
        </header>

        <main className="content-container">
          {/* KPI Summary Row */}
          <section className="kpi-grid">
            <div className={`kpi-card ${isAlert ? 'alert-card' : ''}`}>
              <div>
                <div className="kpi-label">Status Kawasan</div>
                <div className={`kpi-value ${isAlert ? 'danger' : 'emerald'}`} style={{ fontSize: '1.25rem' }}>
                  {isAlert
                    ? 'MEROKOK TERDETEKSI'
                    : isVerifying
                    ? `VERIFIKASI (${status.consecutive_hits}/${minConsecutiveFrames})`
                    : 'KAWASAN AMAN'}
                </div>
                <div className="kpi-sub">
                  Confidence Maks: {(status.max_confidence * 100).toFixed(1)}%
                </div>
              </div>
              <div className={`kpi-icon-box ${isAlert ? 'danger' : ''}`}>
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                  <line x1="12" y1="9" x2="12" y2="13" />
                  <line x1="12" y1="17" x2="12.01" y2="17" />
                </svg>
              </div>
            </div>

            <div className="kpi-card">
              <div>
                <div className="kpi-label">Jumlah Orang di Kamera</div>
                <div className="kpi-value">{status.person_count} Orang</div>
                <div className="kpi-sub">
                  Terkonfirmasi Merokok: <strong>{status.smoker_count} Orang</strong>
                </div>
              </div>
              <div className="kpi-icon-box">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                  <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
              </div>
            </div>

            <div className="kpi-card">
              <div>
                <div className="kpi-label">Titik Rokok Terkonfirmasi</div>
                <div className={`kpi-value ${status.cigarette_count > 0 ? 'danger' : 'emerald'}`}>
                  {status.cigarette_count} Batang
                </div>
                <div className="kpi-sub">
                  Ambang Confidence Aktif: <strong>{Math.round(confThreshold * 100)}%</strong>
                </div>
              </div>
              <div className="kpi-icon-box">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <path d="M18 12H2v4h16" />
                  <path d="M22 12v4" />
                  <path d="M7 12v4" />
                  <path d="M18 8c0-2.5-2-2.5-2-5" />
                  <path d="M22 8c0-2.5-2-2.5-2-5" />
                </svg>
              </div>
            </div>

            <div className="kpi-card">
              <div>
                <div className="kpi-label">Kecepatan Inferensi</div>
                <div className="kpi-value emerald">{status.fps} FPS</div>
                <div className="kpi-sub">
                  Waktu Proses: {status.inference_ms} ms / frame
                </div>
              </div>
              <div className="kpi-icon-box">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
                </svg>
              </div>
            </div>
          </section>

          {/* TAB 1: LIVE MONITOR */}
          {activeTab === 'monitor' && (
            <section className="monitor-grid">
              {/* Left: Live Stream Card */}
              <div className="card">
                <div className="card-header">
                  <div className="card-title-group">
                    <span className="pulse-dot" />
                    <div>
                      <div className="card-title">Live Visual Feed — {status.camera_name}</div>
                      <div className="card-subtitle">
                        {sourceMode === 'webcam'
                          ? 'Kamera Webcam Aktif • Real-Time Stream'
                          : `Frame ${status.current_frame} / ${status.total_frames} • Resolusi HD 1280×720`}
                      </div>
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button className="btn" onClick={handleTogglePause}>
                      {paused ? <IconPlay /> : <IconPause />}
                      <span>{paused ? 'Lanjutkan Stream' : 'Jeda Video'}</span>
                    </button>
                    <button className="btn btn-primary" onClick={handleManualCapture}>
                      <IconCamera size={15} />
                      <span>Ambil Snapshot Manual</span>
                    </button>
                  </div>
                </div>

                <div className="video-viewport">
                  <img
                    key={`${sourceMode}-${streamKey}`}
                    src={`${API_BASE}/api/stream/?source=${sourceMode}&t=${streamKey}`}
                    alt="Live CCTV Stream"
                    className="video-stream-img"
                  />
                  <div className="video-overlay-bar">
                    <div className="cam-badge">
                      <span className="pulse-dot" />
                      <span>LIVE • {status.camera_name}</span>
                    </div>
                    <div className="mode-chip" style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                      <IconCheck />
                      <span>
                        {twoStage ? 'Two-Stage (Person ROI + Rokok)' : 'Single-Stage Standard'} • Conf {Math.round(confThreshold * 100)}%
                      </span>
                    </div>
                  </div>
                </div>

                {/* Source Mode Sub-Tabs */}
                <div className="video-toolbar">
                  <div className="toolbar-group">
                    <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#476658' }}>
                      Tab Sumber Input:
                    </span>
                    <button
                      className={`btn ${sourceMode === 'cctv_demo' ? 'btn-primary' : ''}`}
                      onClick={() => handleSelectSource('cctv_demo')}
                    >
                      <IconVideo />
                      <span>CCTV Indoor (Video Demo)</span>
                    </button>

                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="video/*"
                      style={{ display: 'none' }}
                      onChange={handleVideoUpload}
                    />
                    <button
                      className={`btn ${sourceMode === 'custom_video' ? 'btn-primary' : ''}`}
                      onClick={() => fileInputRef.current?.click()}
                    >
                      <IconUpload />
                      <span>Upload Video MP4</span>
                    </button>

                    <button
                      className={`btn ${sourceMode === 'webcam' ? 'btn-primary' : ''}`}
                      onClick={() => handleSelectSource('webcam')}
                    >
                      <IconWebcam />
                      <span>Kamera Webcam</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* Right: Control & Recent Snapshots */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div className="card">
                  <div className="card-header">
                    <div className="card-title-group">
                      <IconSliders />
                      <div>
                        <div className="card-title">Pengaturan Deteksi AI</div>
                        <div className="card-subtitle">Kontrol Real-Time Pipeline YOLOv8</div>
                      </div>
                    </div>
                  </div>
                  <div className="control-body">
                    <div className="control-row">
                      <div className="control-row-info">
                        <h4>Mode Two-Stage (Anti-Tiang)</h4>
                        <p>Deteksi orang dulu (ROI) baru deteksi rokok agar tiang tidak salah deteksi</p>
                      </div>
                      <label className="switch">
                        <input
                          type="checkbox"
                          checked={twoStage}
                          onChange={(e) => handleToggleTwoStage(e.target.checked)}
                        />
                        <span className="slider" />
                      </label>
                    </div>

                    <div className="control-row">
                      <div className="control-row-info">
                        <h4>Tampilkan Kotak Orang</h4>
                        <p>Kotak Hijau (AMAN), Kuning (VERIFIKASI), & Merah (MEROKOK)</p>
                      </div>
                      <label className="switch">
                        <input
                          type="checkbox"
                          checked={showPersonBox}
                          onChange={(e) => handleTogglePersonBox(e.target.checked)}
                        />
                        <span className="slider" />
                      </label>
                    </div>

                    {/* Confidence Threshold Slider */}
                    <div className="range-box">
                      <div className="range-header">
                        <span>Confidence Threshold Rokok</span>
                        <span style={{ color: '#059669', fontSize: '0.92rem' }}>
                          {Math.round(confThreshold * 100)}%
                        </span>
                      </div>
                      <input
                        type="range"
                        min="0.15"
                        max="0.85"
                        step="0.05"
                        value={confThreshold}
                        onChange={(e) => handleConfChange(e.target.value)}
                        className="range-input"
                      />
                      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '6px', marginTop: '4px' }}>
                        {[
                          { label: 'Sensitif 25%', val: 0.25 },
                          { label: 'Default 45%', val: 0.45 },
                          { label: 'Ketat 65%', val: 0.65 },
                          { label: 'Sangat Ketat 80%', val: 0.80 },
                        ].map((preset) => (
                          <button
                            key={preset.val}
                            type="button"
                            onClick={() => handleConfChange(preset.val)}
                            style={{
                              flex: 1,
                              padding: '5px 4px',
                              fontSize: '0.69rem',
                              fontWeight: 700,
                              borderRadius: '7px',
                              border: Math.abs(confThreshold - preset.val) < 0.02 ? '1px solid #059669' : '1px solid #e2eee8',
                              background: Math.abs(confThreshold - preset.val) < 0.02 ? '#ecfdf5' : '#ffffff',
                              color: Math.abs(confThreshold - preset.val) < 0.02 ? '#047857' : '#476658',
                              cursor: 'pointer',
                            }}
                          >
                            {preset.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Anti-False Positive Consecutive Frames Filter */}
                    <div className="range-box">
                      <div className="range-header">
                        <span>Filter Snapshot (Min Frame Berturut)</span>
                        <span style={{ color: '#059669', fontSize: '0.88rem' }}>
                          {minConsecutiveFrames} Frame
                        </span>
                      </div>
                      <input
                        type="range"
                        min="5"
                        max="25"
                        step="1"
                        value={minConsecutiveFrames}
                        onChange={(e) => handleConsecutiveFramesChange(e.target.value)}
                        className="range-input"
                      />
                      <div style={{ fontSize: '0.72rem', color: '#476658', display: 'flex', justifyContent: 'space-between' }}>
                        <span>Status Verifikasi Saat Ini:</span>
                        <strong>{status.consecutive_hits} / {minConsecutiveFrames} Frame ({verifyPct}%)</strong>
                      </div>
                      <div style={{ width: '100%', height: '6px', background: '#e2eee8', borderRadius: '99px', overflow: 'hidden' }}>
                        <div
                          style={{
                            width: `${verifyPct}%`,
                            height: '100%',
                            background: verifyPct >= 100 ? '#ef4444' : '#10b981',
                            transition: 'width 0.2s ease',
                          }}
                        />
                      </div>
                    </div>
                  </div>
                </div>

                {/* Recent Incidents Feed */}
                <div className="card">
                  <div className="card-header">
                    <div>
                      <div className="card-title">Snapshot Pelanggaran Terkonfirmasi</div>
                      <div className="card-subtitle">Hanya disimpan jika rokok konsisten &ge; {minConsecutiveFrames} frame</div>
                    </div>
                    <button
                      className="btn"
                      style={{ padding: '6px 10px', fontSize: '0.75rem' }}
                      onClick={() => handleSwitchMainTab('incidents')}
                    >
                      Lihat Semua
                    </button>
                  </div>

                  <div className="incident-mini-list">
                    {incidents.length === 0 ? (
                      <div style={{ textAlign: 'center', padding: '24px 12px', color: '#759485', fontSize: '0.84rem' }}>
                        Belum ada snapshot pelanggaran terkonfirmasi.
                      </div>
                    ) : (
                      incidents.slice(0, 6).map((item) => (
                        <div
                          key={item.id}
                          className="incident-mini-item"
                          onClick={() => setSelectedIncident(item)}
                        >
                          <img
                            src={`${API_BASE}${item.snapshot_url}`}
                            alt="Snapshot"
                            className="incident-thumb"
                          />
                          <div className="incident-meta">
                            <h5>{item.cigarette_count} Rokok Terkonfirmasi</h5>
                            <p>{item.timestamp} • Frame #{item.frame_number}</p>
                          </div>
                          <span className="conf-tag">
                            {(item.max_confidence * 100).toFixed(0)}%
                          </span>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              </div>
            </section>
          )}

          {/* TAB 2: INCIDENT LOG GALLERY */}
          {activeTab === 'incidents' && (
            <section className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">Galeri Bukti Pelanggaran Kawasan Tanpa Rokok</div>
                  <div className="card-subtitle">
                    Hanya menangkap snapshot setelah terdeteksi konsisten minimal {minConsecutiveFrames} frame berturut-turut (bebas false positive 1-frame)
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '10px' }}>
                  <button className="btn btn-danger-outline" onClick={handleClearIncidents}>
                    <IconTrash />
                    <span>Bersihkan Riwayat</span>
                  </button>
                </div>
              </div>

              {incidents.length === 0 ? (
                <div style={{ padding: '48px', textAlign: 'center', color: '#759485' }}>
                  Belum ada data pelanggaran terkonfirmasi. Buka tab Live Monitoring untuk memantau secara otomatis.
                </div>
              ) : (
                <div className="gallery-grid">
                  {incidents.map((item) => (
                    <div
                      key={item.id}
                      className="gallery-card"
                      onClick={() => setSelectedIncident(item)}
                    >
                      <img
                        src={`${API_BASE}${item.snapshot_url}`}
                        alt={`Incident ${item.id}`}
                        className="gallery-img"
                      />
                      <div className="gallery-body">
                        <div className="gallery-top">
                          <span className="gallery-title">{item.camera_name}</span>
                          <span className="conf-tag">Conf {(item.max_confidence * 100).toFixed(0)}%</span>
                        </div>
                        <div style={{ fontSize: '0.78rem', color: '#059669', fontWeight: 700 }}>
                          {item.cigarette_count} Titik Rokok • {item.person_count} Orang di Frame
                        </div>
                        <div className="gallery-sub">
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px' }}>
                            <IconClock />
                            {item.timestamp}
                          </span>
                          <span>Frame #{item.frame_number}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          )}

          {/* TAB 3: TA MODEL EVALUATION METRICS */}
          {activeTab === 'metrics' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '22px' }}>
              <div className="kpi-grid">
                <div className="kpi-card">
                  <div>
                    <div className="kpi-label">mAP@50 (Data Validation)</div>
                    <div className="kpi-value emerald">{metrics?.val_map50 ?? 94.7}%</div>
                    <div className="kpi-sub">1.726 Gambar Validasi (4.287 Instance)</div>
                  </div>
                </div>
                <div className="kpi-card">
                  <div>
                    <div className="kpi-label">mAP@50 (Data Testing)</div>
                    <div className="kpi-value emerald">{metrics?.test_map50 ?? 94.2}%</div>
                    <div className="kpi-sub">872 Gambar Testing (2.143 Instance)</div>
                  </div>
                </div>
                <div className="kpi-card">
                  <div>
                    <div className="kpi-label">Precision & Recall (Val)</div>
                    <div className="kpi-value">{metrics?.val_precision ?? 93.8}% / {metrics?.val_recall ?? 89.3}%</div>
                    <div className="kpi-sub">mAP@50-95: {metrics?.val_map50_95 ?? 72.1}%</div>
                  </div>
                </div>
                <div className="kpi-card">
                  <div>
                    <div className="kpi-label">Total Dataset Training</div>
                    <div className="kpi-value">8.666 Citra</div>
                    <div className="kpi-sub">6.068 Train • 1.726 Val • 872 Test (50 Epoch)</div>
                  </div>
                </div>
              </div>

              <div className="metrics-two-col">
                <div className="card">
                  <div className="card-header">
                    <div>
                      <div className="card-title">Grafik Kenaikan Akurasi mAP@50 (Epoch 1–50)</div>
                      <div className="card-subtitle">Meningkat dari 56.2% (Epoch 1) hingga 94.7% (Epoch 50)</div>
                    </div>
                  </div>
                  <div className="chart-box">
                    <SvgLineChart
                      data={metrics?.epochs || []}
                      yKey="map50"
                      color="#059669"
                      unit="%"
                      minY={50}
                      maxY={100}
                      label="Progres mAP@50 Selama 50 Epoch Training"
                    />
                  </div>
                </div>

                <div className="card">
                  <div className="card-header">
                    <div>
                      <div className="card-title">Grafik Penurunan Box Loss Training (Epoch 1–50)</div>
                      <div className="card-subtitle">Konvergensi Box Loss dari 1.68 menuju 0.84</div>
                    </div>
                  </div>
                  <div className="chart-box">
                    <SvgLineChart
                      data={metrics?.epochs || []}
                      yKey="box_loss"
                      color="#10b981"
                      unit=""
                      minY={0.7}
                      maxY={1.8}
                      label="Penurunan Train Box Loss Selama 50 Epoch"
                    />
                  </div>
                </div>
              </div>

              <div className="card">
                <div className="card-header">
                  <div>
                    <div className="card-title">Arsitektur Two-Stage Detection + Temporal Filter untuk Kamera CCTV</div>
                    <div className="card-subtitle">
                      Solusi mengatasi perbedaan jarak kamera (Domain Shift) & False Positive 1-Frame
                    </div>
                  </div>
                </div>
                <div className="pipeline-steps">
                  <div className="pipeline-step">
                    <span className="step-num">TAHAP 1 • PERSON ROI</span>
                    <h4>Deteksi Orang (YOLOv8n COCO)</h4>
                    <p>
                      Mendeteksi koordinat setiap orang di dalam ruangan terlebih dahulu. Objek statis di luar tubuh manusia (seperti tiang kayu coklat, jendela, lemari) otomatis diabaikan.
                    </p>
                  </div>
                  <div className="pipeline-step">
                    <span className="step-num">TAHAP 2 • HD CROPPING</span>
                    <h4>Crop Area Tubuh Atas & Tangan</h4>
                    <p>
                      Memotong area kepala hingga tangan tiap orang pada resolusi asli (1280×720) lalu di-upscale ke 640×640 agar batang rokok kecil terlihat besar dan jelas oleh model.
                    </p>
                  </div>
                  <div className="pipeline-step">
                    <span className="step-num">TAHAP 3 • TEMPORAL FILTER</span>
                    <h4>Verifikasi Frame Berturut-turut</h4>
                    <p>
                      Deteksi sesaat (1–3 frame karena gangguan visual) hanya berstatus Verifikasi dan tidak masuk ke Snapshot. Snapshot hanya diambil jika rokok konsisten &ge; {minConsecutiveFrames} frame.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </main>
      </div>

      {/* Snapshot Zoom Modal */}
      {selectedIncident && (
        <div className="modal-backdrop" onClick={() => setSelectedIncident(null)}>
          <div className="modal-box" onClick={(e) => e.stopPropagation()}>
            <div className="card-header">
              <div>
                <div className="card-title">
                  Detail Bukti Pelanggaran — {selectedIncident.camera_name}
                </div>
                <div className="card-subtitle">
                  Waktu: {selectedIncident.timestamp} • Frame #{selectedIncident.frame_number} • Mode: {selectedIncident.detection_mode}
                </div>
              </div>
              <button className="btn" onClick={() => setSelectedIncident(null)}>
                <IconClose />
                <span>Tutup</span>
              </button>
            </div>
            <img
              src={`${API_BASE}${selectedIncident.snapshot_url}`}
              alt="Detail Pelanggaran"
              className="modal-img"
            />
          </div>
        </div>
      )}
    </div>
  )
}
