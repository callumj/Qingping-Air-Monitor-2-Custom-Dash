import QtQuick 2.12

Canvas {
    id: glyph
    width: 44
    height: 44

    property string condition: ""
    property color ink: "#f4efe4"
    property color accent: "#c49a45"
    property color muted: "#9e988b"

    onConditionChanged: requestPaint()
    onInkChanged: requestPaint()
    onAccentChanged: requestPaint()
    onMutedChanged: requestPaint()

    function has(name) {
        return condition.toLowerCase().indexOf(name) >= 0;
    }

    function drawSun(ctx, x, y, radius) {
        ctx.strokeStyle = accent;
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2, false);
        ctx.stroke();
        for (var i = 0; i < 8; i += 1) {
            var angle = (Math.PI * 2 / 8) * i;
            ctx.beginPath();
            ctx.moveTo(x + Math.cos(angle) * (radius + 5), y + Math.sin(angle) * (radius + 5));
            ctx.lineTo(x + Math.cos(angle) * (radius + 10), y + Math.sin(angle) * (radius + 10));
            ctx.stroke();
        }
    }

    function drawCloud(ctx, x, y, color) {
        ctx.strokeStyle = color;
        ctx.beginPath();
        ctx.arc(x + 10, y + 9, 8, Math.PI, Math.PI * 1.65, false);
        ctx.arc(x + 22, y + 5, 11, Math.PI * 1.12, Math.PI * 1.86, false);
        ctx.arc(x + 34, y + 11, 8, Math.PI * 1.45, Math.PI * 2, false);
        ctx.lineTo(x + 36, y + 20);
        ctx.lineTo(x + 8, y + 20);
        ctx.arc(x + 8, y + 13, 7, Math.PI * 0.5, Math.PI, false);
        ctx.stroke();
    }

    function drawRain(ctx) {
        ctx.strokeStyle = accent;
        for (var i = 0; i < 3; i += 1) {
            ctx.beginPath();
            ctx.moveTo(16 + i * 7, 32);
            ctx.lineTo(13 + i * 7, 39);
            ctx.stroke();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        if (ctx.resetTransform) {
            ctx.resetTransform();
        } else if (ctx.setTransform) {
            ctx.setTransform(1, 0, 0, 1, 0, 0);
        }
        ctx.clearRect(0, 0, width, height);
        ctx.save();
        ctx.scale(width / 44, height / 44);
        ctx.lineWidth = 2.2;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        var cloudy = has("cloud");
        var rainy = has("rain") || has("pour");
        var sunny = has("sun") || has("clear");

        if (sunny && !cloudy) {
            drawSun(ctx, 22, 22, 9);
        } else if (cloudy || rainy) {
            if (condition.toLowerCase() === "partlycloudy") {
                drawSun(ctx, 16, 16, 7);
            }
            drawCloud(ctx, 3, 13, ink);
            if (rainy) drawRain(ctx);
        } else {
            ctx.strokeStyle = muted;
            ctx.beginPath();
            ctx.arc(22, 22, 12, 0, Math.PI * 2, false);
            ctx.stroke();
        }
        ctx.restore();
    }
}

