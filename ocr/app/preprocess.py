"""OpenCV preprocessing: resize, crop the document (4-point warp), deskew, contrast."""

from __future__ import annotations

import cv2
import numpy as np


def decode(data: bytes) -> np.ndarray | None:
    arr = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    return arr


def resize(img: np.ndarray, max_side: int) -> np.ndarray:
    h, w = img.shape[:2]
    s = max_side / max(h, w)
    if s >= 1:
        return img
    return cv2.resize(img, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA)


def _order(pts: np.ndarray) -> np.ndarray:
    s, d = pts.sum(1), np.diff(pts, axis=1).ravel()
    return np.array([pts[s.argmin()], pts[d.argmin()], pts[s.argmax()], pts[d.argmax()]], np.float32)


def crop_document(img: np.ndarray) -> np.ndarray:
    """Warp to the document if a clear 4-corner outline covers 30-98 % of the photo."""
    gray = cv2.GaussianBlur(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY), (5, 5), 0)
    edges = cv2.dilate(cv2.Canny(gray, 50, 150), np.ones((3, 3), np.uint8))
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    area = img.shape[0] * img.shape[1]
    for c in sorted(contours, key=cv2.contourArea, reverse=True)[:5]:
        approx = cv2.approxPolyDP(c, 0.02 * cv2.arcLength(c, True), True)
        if len(approx) == 4 and 0.30 * area < cv2.contourArea(approx) < 0.98 * area:
            tl, tr, br, bl = q = _order(approx.reshape(4, 2).astype(np.float32))
            w = int(max(np.linalg.norm(br - bl), np.linalg.norm(tr - tl)))
            h = int(max(np.linalg.norm(tr - br), np.linalg.norm(tl - bl)))
            dst = np.array([[0, 0], [w - 1, 0], [w - 1, h - 1], [0, h - 1]], np.float32)
            return cv2.warpPerspective(img, cv2.getPerspectiveTransform(q, dst), (w, h))
    return img


def skew_angle(img: np.ndarray) -> float:
    """Dominant text angle in degrees from the dark-pixel cloud (0 if unsure)."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    bw = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)[1]
    # join characters into text lines, then measure each line
    blobs = cv2.morphologyEx(bw, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (25, 3)))
    contours, _ = cv2.findContours(blobs, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    angles = []
    for c in contours:
        (_, _), (w, h), a = cv2.minAreaRect(c)
        if max(w, h) < 60 or min(w, h) < 5 or max(w, h) / max(1, min(w, h)) < 3:
            continue
        if w < h:
            a -= 90
        if a > 45:
            a -= 90
        if a < -45:
            a += 90
        angles.append(a)
    if len(angles) < 3:
        return 0.0
    return float(np.median(angles))


def deskew(img: np.ndarray) -> np.ndarray:
    a = skew_angle(img)
    if abs(a) < 0.5 or abs(a) > 15:
        return img
    h, w = img.shape[:2]
    m = cv2.getRotationMatrix2D((w / 2, h / 2), a, 1.0)
    return cv2.warpAffine(img, m, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)


def contrast(img: np.ndarray) -> np.ndarray:
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    l = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(l)
    return cv2.cvtColor(cv2.merge((l, a, b)), cv2.COLOR_LAB2BGR)


def preprocess(img: np.ndarray, max_side: int = 1600) -> np.ndarray:
    return contrast(deskew(crop_document(resize(img, max_side))))
