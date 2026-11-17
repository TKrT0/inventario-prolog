"""Prueba la UI con un servidor que use un archivo de datos temporal."""

import argparse
from pathlib import Path
import re
import subprocess
import tempfile

from playwright.sync_api import expect, sync_playwright


INICIALES = {
    "monster_energy": (4, 10),
    "croquetas_perro": (2, 5),
    "lapiceros_pentel": (1, 3),
    "agua_embotellada": (20, 15),
    "galletas": (5, 10),
}


def luminancia(color):
    canales = [float(valor) / 255 for valor in re.findall(r"[\d.]+", color)[:3]]
    lineales = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in canales]
    return sum(c * peso for c, peso in zip(lineales, [0.2126, 0.7152, 0.0722]))


def comprobar(url):
    capturas = Path(__file__).resolve().parents[1] / ".impeccable" / "review"
    capturas.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 900})
        errores = []
        page.on("pageerror", lambda error: errores.append(str(error)))

        def restaurar():
            for producto, (cantidad, minimo) in INICIALES.items():
                respuesta = page.request.put(
                    f"{url}/api/inventario/{producto}",
                    data={"cantidad": cantidad, "minimo": minimo},
                )
                assert respuesta.ok, respuesta.text()

        restaurar()
        try:
            page.goto(url)
            page.wait_for_load_state("networkidle")
            expect(page.locator("#inventario-body tr")).to_have_count(5)
            expect(page.locator("#compras-body tr")).to_have_count(4)

            editar = page.locator('button[data-producto="croquetas_perro"]')
            existencias = page.get_by_role("spinbutton", name="Existencias", exact=True)
            editar.click()
            expect(existencias).to_be_focused()
            existencias.fill("5")
            page.get_by_role("button", name="Guardar cambios").click()
            expect(page.locator("#compras-body tr")).to_have_count(3)
            expect(page.locator("#editor")).to_be_hidden()
            expect(page.get_by_role("status")).to_contain_text("Cambios guardados")

            editar.click()
            existencias.fill("100")
            page.route("**/api/inventario/croquetas_perro",
                       lambda route: route.fulfill(status=500, json={"error": "No se pudo guardar. Intenta de nuevo."}))
            page.get_by_role("button", name="Guardar cambios").click()
            expect(page.locator("#error-formulario")).to_contain_text("No se pudo guardar")
            expect(existencias).to_have_value("100")
            expect(page.get_by_role("button", name="Guardar cambios")).to_be_enabled()
            expect(page.get_by_role("button", name="Guardar cambios")).to_be_focused()
            page.unroute("**/api/inventario/croquetas_perro")

            page.route("**/api/inventario/croquetas_perro", lambda route: route.abort("failed"))
            page.get_by_role("button", name="Guardar cambios").click()
            expect(page.locator("#error-formulario")).to_contain_text("confirmar")
            expect(existencias).to_have_value("100")
            page.unroute("**/api/inventario/croquetas_perro")
            page.get_by_role("button", name="Cancelar").click()
            expect(editar).to_be_focused()

            for producto, (cantidad, minimo) in INICIALES.items():
                respuesta = page.request.put(f"{url}/api/inventario/{producto}",
                                             data={"cantidad": max(cantidad, minimo), "minimo": minimo})
                assert respuesta.ok
            page.get_by_role("button", name="Actualizar", exact=True).click()
            expect(page.locator("#sin-compras")).to_be_visible()
            expect(page.locator("#compras-body tr")).to_have_count(0)

            restaurar()
            page.reload()
            page.wait_for_load_state("networkidle")
            expect(page.locator("#compras-body tr")).to_have_count(4)
            page.screenshot(path=str(capturas / "desktop.png"), full_page=True)
            page.set_viewport_size({"width": 390, "height": 844})
            page.emulate_media(reduced_motion="reduce")
            page.screenshot(path=str(capturas / "mobile.png"), full_page=True)
            assert page.evaluate("document.documentElement.scrollWidth <= innerWidth"), page.evaluate("""() => ({
                viewport: innerWidth, ancho: document.documentElement.scrollWidth,
                elementos: [...document.querySelectorAll('body *')].filter(e =>
                    e.getBoundingClientRect().right > innerWidth + 1 && !e.closest('.tabla-scroll')
                ).map(e => [e.tagName, e.className, e.getBoundingClientRect().width]).slice(0, 10)
            })""")
            editar.click()
            expect(existencias).to_be_focused()
            colores = existencias.evaluate("el => ({borde: getComputedStyle(el).borderTopColor, fondo: getComputedStyle(el).backgroundColor})")
            niveles = sorted([luminancia(colores["borde"]), luminancia(colores["fondo"])])
            contraste = (niveles[1] + 0.05) / (niveles[0] + 0.05)
            assert contraste >= 3, f"Contraste de borde insuficiente: {contraste:.2f}:1"
            page.screenshot(path=str(capturas / "mobile-edit.png"), full_page=True)
            page.set_viewport_size({"width": 375, "height": 812})
            assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
            page.set_viewport_size({"width": 1440, "height": 900})
            with page.expect_response(lambda r: r.url == f"{url}/"):
                page.evaluate("url => { const f = document.createElement('iframe'); f.id = 'prueba-frame'; f.src = url; document.body.append(f); }", f"{url}/")
            page.wait_for_load_state("networkidle")
            expect(page.frame_locator("#prueba-frame").locator("#inventario-body tr")).to_have_count(0)
            assert not errores, errores
            print("PASS: carga, edición, persistencia vía API, error de servidor, error de red, teclado, estado vacío y vistas desktop/móvil.")
        finally:
            restaurar()
            browser.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swipl", default="swipl", help="Ejecutable SWI-Prolog")
    args = parser.parse_args()
    servidor = Path(__file__).resolve().parents[1] / "servidor.pl"
    with tempfile.TemporaryDirectory(prefix="inventario-ui-") as directorio:
        archivo = (Path(directorio) / "inventario.json").as_posix().replace("'", "''")
        objetivo = f"iniciar_servidor(P,'{archivo}'),format('~d~n',[P]),flush_output,thread_get_message(_)"
        proceso = subprocess.Popen([args.swipl, "-q", "-l", str(servidor), "-g", objetivo],
                                   stdout=subprocess.PIPE, text=True)
        try:
            puerto = proceso.stdout.readline().strip()
            if not puerto.isdecimal():
                raise RuntimeError("El servidor de prueba no pudo iniciarse.")
            comprobar(f"http://127.0.0.1:{puerto}")
        finally:
            proceso.terminate()
            try:
                proceso.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proceso.kill()
                proceso.wait()
