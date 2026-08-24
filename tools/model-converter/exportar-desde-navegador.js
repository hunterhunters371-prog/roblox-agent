/* Exportador de escenas 3D generadas por codigo, desde la consola del navegador.
 *
 * Sirve para paginas HTML que construyen la geometria con JavaScript (three.js,
 * babylon con adaptador, etc.). Un analisis estatico del HTML no puede recuperar
 * esa geometria porque solo existe mientras el navegador ejecuta el codigo, asi
 * que la exportacion tiene que ocurrir dentro de la propia pagina.
 *
 * Uso:
 *   1. Abre el HTML en el navegador y espera a que se vea el modelo.
 *   2. Abre la consola (F12 o Ctrl+Mayus+J).
 *   3. Pega todo este archivo y pulsa Enter.
 *   4. Se descargan escena.obj y escena.mtl.
 *   5. Sube esos dos archivos al conversor, mejor comprimidos en un ZIP.
 *
 * No depende de ninguna biblioteca externa: lee los atributos de geometria por
 * duck typing, aplica la matriz de mundo de cada malla y escribe OBJ y MTL.
 */
(function () {
	"use strict";

	var LIMITE_PROFUNDIDAD = 3;

	function esObjeto3D(valor) {
		return (
			valor &&
			typeof valor === "object" &&
			valor.isObject3D === true &&
			Array.isArray(valor.children)
		);
	}

	function esEscena(valor) {
		if (!esObjeto3D(valor)) return false;
		return valor.isScene === true || valor.children.length > 0;
	}

	function buscarEscenas(raiz) {
		var vistos = new Set();
		var encontradas = [];

		function recorrer(objeto, nivel) {
			if (!objeto || typeof objeto !== "object") return;
			if (nivel > LIMITE_PROFUNDIDAD || vistos.has(objeto)) return;
			vistos.add(objeto);
			var claves;
			try {
				claves = Object.keys(objeto);
			} catch (error) {
				return;
			}
			for (var i = 0; i < claves.length; i++) {
				var valor;
				try {
					valor = objeto[claves[i]];
				} catch (error) {
					continue;
				}
				if (esEscena(valor)) {
					if (encontradas.indexOf(valor) === -1) encontradas.push(valor);
					continue;
				}
				if (valor && typeof valor === "object" && nivel < LIMITE_PROFUNDIDAD) {
					recorrer(valor, nivel + 1);
				}
			}
		}

		recorrer(raiz, 0);
		return encontradas;
	}

	function mallasDe(escena) {
		var mallas = [];
		if (typeof escena.updateMatrixWorld === "function") {
			try {
				escena.updateMatrixWorld(true);
			} catch (error) {
				/* sin matrices actualizadas se usa la identidad */
			}
		}
		function visitar(objeto) {
			if (!objeto) return;
			if (objeto.isMesh === true && objeto.geometry) mallas.push(objeto);
			var hijos = objeto.children || [];
			for (var i = 0; i < hijos.length; i++) visitar(hijos[i]);
		}
		visitar(escena);
		return mallas;
	}

	function matrizDe(objeto) {
		var identidad = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
		var matriz = objeto.matrixWorld && objeto.matrixWorld.elements;
		if (!matriz || matriz.length !== 16) return identidad;
		return matriz;
	}

	function aplicar(matriz, x, y, z) {
		return [
			matriz[0] * x + matriz[4] * y + matriz[8] * z + matriz[12],
			matriz[1] * x + matriz[5] * y + matriz[9] * z + matriz[13],
			matriz[2] * x + matriz[6] * y + matriz[10] * z + matriz[14],
		];
	}

	function aplicarDireccion(matriz, x, y, z) {
		return [
			matriz[0] * x + matriz[4] * y + matriz[8] * z,
			matriz[1] * x + matriz[5] * y + matriz[9] * z,
			matriz[2] * x + matriz[6] * y + matriz[10] * z,
		];
	}

	function numero(valor) {
		if (!isFinite(valor)) return "0";
		return (Math.round(valor * 1000000) / 1000000).toString();
	}

	function nombreMaterial(material, indice) {
		var bruto = (material && (material.name || material.type)) || "material";
		var limpio = String(bruto).replace(/[^A-Za-z0-9_.-]/g, "_");
		return limpio + "_" + indice;
	}

	function colorDe(material) {
		var color = material && material.color;
		if (!color) return [0.8, 0.8, 0.8];
		return [
			typeof color.r === "number" ? color.r : 0.8,
			typeof color.g === "number" ? color.g : 0.8,
			typeof color.b === "number" ? color.b : 0.8,
		];
	}

	function exportar(escena) {
		var mallas = mallasDe(escena);
		if (mallas.length === 0) {
			throw new Error("La escena no contiene mallas con geometria.");
		}

		var obj = ["# Exportado desde el navegador por model-converter", "mtllib escena.mtl"];
		var materiales = [];
		var nombresMateriales = new Map();
		var desplazamientoV = 1;
		var desplazamientoT = 1;
		var desplazamientoN = 1;
		var totalTriangulos = 0;
		var omitidas = 0;

		for (var m = 0; m < mallas.length; m++) {
			var malla = mallas[m];
			var geometria = malla.geometry;
			var atributos = geometria && geometria.attributes;
			var posicion = atributos && atributos.position;
			if (!posicion || !posicion.array) {
				omitidas++;
				continue;
			}
			var posiciones = posicion.array;
			var cuenta = posiciones.length / (posicion.itemSize || 3);
			var normales = atributos.normal && atributos.normal.array;
			var uv = atributos.uv && atributos.uv.array;
			var indice = geometria.index && geometria.index.array;
			var matriz = matrizDe(malla);

			var material = Array.isArray(malla.material) ? malla.material[0] : malla.material;
			var nombreMat = nombresMateriales.get(material);
			if (!nombreMat) {
				nombreMat = nombreMaterial(material, materiales.length);
				nombresMateriales.set(material, nombreMat);
				materiales.push({ nombre: nombreMat, material: material });
			}

			obj.push("o " + String(malla.name || "malla_" + m).replace(/\s+/g, "_"));
			for (var v = 0; v < cuenta; v++) {
				var p = aplicar(matriz, posiciones[v * 3], posiciones[v * 3 + 1], posiciones[v * 3 + 2]);
				obj.push("v " + numero(p[0]) + " " + numero(p[1]) + " " + numero(p[2]));
			}
			if (uv) {
				for (var t = 0; t < cuenta; t++) {
					obj.push("vt " + numero(uv[t * 2]) + " " + numero(uv[t * 2 + 1]));
				}
			}
			if (normales) {
				for (var n = 0; n < cuenta; n++) {
					var d = aplicarDireccion(matriz, normales[n * 3], normales[n * 3 + 1], normales[n * 3 + 2]);
					var largo = Math.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]) || 1;
					obj.push("vn " + numero(d[0] / largo) + " " + numero(d[1] / largo) + " " + numero(d[2] / largo));
				}
			}

			obj.push("usemtl " + nombreMat);
			var total = indice ? indice.length : cuenta;
			for (var i = 0; i + 2 < total; i += 3) {
				var a = (indice ? indice[i] : i) + 0;
				var b = (indice ? indice[i + 1] : i + 1) + 0;
				var c = (indice ? indice[i + 2] : i + 2) + 0;
				var cara = [];
				var trio = [a, b, c];
				for (var k = 0; k < 3; k++) {
					var vi = trio[k] + desplazamientoV;
					var ti = uv ? trio[k] + desplazamientoT : "";
					var ni = normales ? trio[k] + desplazamientoN : "";
					cara.push(vi + "/" + ti + (ni === "" ? "" : "/" + ni));
				}
				obj.push("f " + cara.join(" "));
				totalTriangulos++;
			}

			desplazamientoV += cuenta;
			if (uv) desplazamientoT += cuenta;
			if (normales) desplazamientoN += cuenta;
		}

		var mtl = ["# Materiales exportados desde el navegador"];
		for (var j = 0; j < materiales.length; j++) {
			var color = colorDe(materiales[j].material);
			mtl.push("newmtl " + materiales[j].nombre);
			mtl.push("Kd " + numero(color[0]) + " " + numero(color[1]) + " " + numero(color[2]));
			mtl.push("Ka 0 0 0");
			mtl.push("Ks 0.1 0.1 0.1");
			var opacidad = materiales[j].material && typeof materiales[j].material.opacity === "number"
				? materiales[j].material.opacity
				: 1;
			mtl.push("d " + numero(opacidad));
		}

		return {
			obj: obj.join("\n") + "\n",
			mtl: mtl.join("\n") + "\n",
			mallas: mallas.length - omitidas,
			omitidas: omitidas,
			triangulos: totalTriangulos,
			materiales: materiales.length,
		};
	}

	function descargar(nombre, texto) {
		var blob = new Blob([texto], { type: "text/plain" });
		var enlace = document.createElement("a");
		enlace.href = URL.createObjectURL(blob);
		enlace.download = nombre;
		document.body.appendChild(enlace);
		enlace.click();
		setTimeout(function () {
			URL.revokeObjectURL(enlace.href);
			enlace.remove();
		}, 1000);
	}

	var escenas = [];
	if (esEscena(window.scene)) escenas.push(window.scene);
	if (escenas.length === 0) escenas = buscarEscenas(window);

	if (escenas.length === 0) {
		console.error(
			"No se encontro ninguna escena. Expon la variable en la consola con " +
				"window.scene = <tu escena> y vuelve a pegar este script."
		);
		return;
	}

	var mejor = escenas[0];
	var mejorCuenta = mallasDe(mejor).length;
	for (var e = 1; e < escenas.length; e++) {
		var cuentaActual = mallasDe(escenas[e]).length;
		if (cuentaActual > mejorCuenta) {
			mejor = escenas[e];
			mejorCuenta = cuentaActual;
		}
	}

	try {
		var resultado = exportar(mejor);
		descargar("escena.obj", resultado.obj);
		descargar("escena.mtl", resultado.mtl);
		console.log(
			"Exportado: " +
				resultado.mallas +
				" mallas, " +
				resultado.triangulos +
				" triangulos, " +
				resultado.materiales +
				" materiales. Omitidas sin geometria: " +
				resultado.omitidas +
				". Sube escena.obj y escena.mtl al conversor."
		);
	} catch (error) {
		console.error("Fallo la exportacion: " + error.message);
	}
})();
