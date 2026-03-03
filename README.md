设置CCTV全屏视频播放
html, body {
    margin: 0 !important;
    padding: 0 !important;
    overflow: hidden !important;
    background: black !important;
}

body * {
    visibility: hidden !important;
}

video, video * {
    visibility: visible !important;
}

video {
    position: fixed !important;
    top: 0 !important;
    left: 0 !important;
    width: 100vw !important;
    height: 100vh !important;
    object-fit: contain !important;
    z-index: 999999 !important;
}
