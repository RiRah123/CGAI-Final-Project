const glCanvas = document.getElementById('glCanvas');
const glContext = glCanvas.getContext('webgl');

if (!glContext) {
    alert('WebGL not supported');
} else {
    function compileShader(gl, shaderType, shaderCode) {
        const shader = gl.createShader(shaderType);
        gl.shaderSource(shader, shaderCode);
        gl.compileShader(shader);

        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            console.error('Shader compile error:', gl.getShaderInfoLog(shader));
            gl.deleteShader(shader);
            return null;
        }
        return shader;
    }

    async function fetchShaderCode(shaderPath) {
        const response = await fetch(shaderPath);
        return await response.text();
    }

    async function setupWebGL() {
        try {
            const vertexShaderCode = `
                attribute vec2 position;
                void main() {
                    gl_Position = vec4(position, 0.0, 1.0);
                }
            `;
            const vertexShader = compileShader(glContext, glContext.VERTEX_SHADER, vertexShaderCode);

            const fragmentShaderCode = await fetchShaderCode('shader.glsl');
            const fragmentShader = compileShader(glContext, glContext.FRAGMENT_SHADER, fragmentShaderCode);

            if (!vertexShader || !fragmentShader) {
                console.error('Failed to create shaders');
                return;
            }

            const shaderProgram = glContext.createProgram();
            glContext.attachShader(shaderProgram, vertexShader);
            glContext.attachShader(shaderProgram, fragmentShader);
            glContext.linkProgram(shaderProgram);

            if (!glContext.getProgramParameter(shaderProgram, glContext.LINK_STATUS)) {
                console.error('Program link error:', glContext.getProgramInfoLog(shaderProgram));
                return;
            }

            const vertexBuffer = glContext.createBuffer();
            glContext.bindBuffer(glContext.ARRAY_BUFFER, vertexBuffer);
            glContext.bufferData(glContext.ARRAY_BUFFER, new Float32Array([
                -1, -1,
                1, -1,
                -1, 1,
                1, 1
            ]), glContext.STATIC_DRAW);

            const resolutionUniform = glContext.getUniformLocation(shaderProgram, 'iResolution');
            const timeUniform = glContext.getUniformLocation(shaderProgram, 'iTime');
            const mouseUniform = glContext.getUniformLocation(shaderProgram, 'iMouse');

            let mousePosX = 0;
            let mousePosY = 0;
            let mousePressed = -1;

            glCanvas.addEventListener('mousemove', (event) => {
                const canvasRect = glCanvas.getBoundingClientRect();
                mousePosX = event.clientX - canvasRect.left;
                mousePosY = event.clientY - canvasRect.top;
                mousePressed = 1;
            });

            glCanvas.addEventListener('mouseup', () => {
                mousePressed = -1;
            });

            function drawFrame() {
                const canvasWidth = glCanvas.clientWidth;
                const canvasHeight = glCanvas.clientHeight;
                if (glCanvas.width !== canvasWidth || glCanvas.height !== canvasHeight) {
                    glCanvas.width = canvasWidth;
                    glCanvas.height = canvasHeight;
                    glContext.viewport(0, 0, glCanvas.width, glCanvas.height);
                }

                glContext.useProgram(shaderProgram);

                glContext.uniform2f(resolutionUniform, glCanvas.width, glCanvas.height);
                glContext.uniform1f(timeUniform, performance.now() / 1000);
                glContext.uniform3f(mouseUniform, mousePosX, mousePosY, mousePressed);

                const positionAttribute = glContext.getAttribLocation(shaderProgram, 'position');
                glContext.enableVertexAttribArray(positionAttribute);
                glContext.vertexAttribPointer(positionAttribute, 2, glContext.FLOAT, false, 0, 0);

                glContext.drawArrays(glContext.TRIANGLE_STRIP, 0, 4);

                requestAnimationFrame(drawFrame);
            }

            drawFrame();
        } catch (error) {
            console.error('Error during initialization:', error);
        }
    }

    setupWebGL();
} 