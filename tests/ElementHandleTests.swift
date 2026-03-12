import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct ElementHandleTests {
		@Test("querySelector finds child element")
		func querySelectorChild() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div class="item"><h2>Title</h2><p>Body</p></div>
				""")
				let item = try await page.querySelector(".item")
				let heading = try await item?.querySelector("h2")
				#expect(heading != nil)
			}
		}

		@Test("querySelector returns nil for non-existent child")
		func querySelectorNilChild() async throws {
			try await withPage { page in
				try await page.setContent("<div class='item'><p>Only a paragraph</p></div>")
				let item = try await page.querySelector(".item")
				let heading = try await item?.querySelector("h2")
				#expect(heading == nil)
			}
		}

		@Test("querySelectorAll returns child elements")
		func querySelectorAllChildren() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")
				let list = try #require(try await page.querySelector("ul"))
				let items = try await list.querySelectorAll("li")
				#expect(items.count == 3)
			}
		}

		@Test("getAttribute returns attribute value")
		func getAttributeValue() async throws {
			try await withPage { page in
				try await page.setContent("<a href='https://example.com' class='link'>Link</a>")
				let element = try #require(try await page.querySelector("a"))
				let href = try await element.getAttribute("href")
				#expect(href == "https://example.com")
			}
		}

		@Test("getAttribute returns nil for missing attribute")
		func getAttributeNil() async throws {
			try await withPage { page in
				try await page.setContent("<div>No attributes</div>")
				let element = try #require(try await page.querySelector("div"))
				let value = try await element.getAttribute("nonexistent")
				#expect(value == nil)
			}
		}

		@Test("innerText returns visible text")
		func innerTextVisible() async throws {
			try await withPage { page in
				try await page.setContent("<div>Hello <span style='display:none'>hidden</span>World</div>")
				let element = try #require(try await page.querySelector("div"))
				let text = try await element.innerText()
				#expect(text.contains("Hello"))
				#expect(text.contains("World"))
				#expect(!text.contains("hidden"))
			}
		}

		@Test("textContent returns raw text including hidden")
		func textContentRaw() async throws {
			try await withPage { page in
				try await page.setContent("<div>Hello <span style='display:none'>hidden</span>World</div>")
				let element = try #require(try await page.querySelector("div"))
				let text = try await element.textContent()
				#expect(text?.contains("hidden") == true)
			}
		}

		@Test("innerHTML returns inner HTML string")
		func innerHTMLContent() async throws {
			try await withPage { page in
				try await page.setContent("<div id='test'><b>Bold</b> text</div>")
				let element = try #require(try await page.querySelector("#test"))
				let html = try await element.innerHTML()
				#expect(html.contains("<b>Bold</b>"))
			}
		}

		@Test("Full scraping workflow: querySelectorAll → iterate → querySelector + getAttribute + innerText")
		func scrapingWorkflow() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div class="card">
						<h3><a href="/page1">Card 1</a></h3>
						<p>Description 1</p>
					</div>
					<div class="card">
						<h3><a href="/page2">Card 2</a></h3>
						<p>Description 2</p>
					</div>
				""")

				let cards = try await page.querySelectorAll(".card")
				#expect(cards.count == 2)

				// Extract data from first card
				let link = try #require(try await cards[0].querySelector("a"))
				let href = try await link.getAttribute("href")
				#expect(href == "/page1")

				let title = try await link.innerText()
				#expect(title == "Card 1")

				// Extract data from second card
				let link2 = try #require(try await cards[1].querySelector("a"))
				let title2 = try await link2.innerText()
				#expect(title2 == "Card 2")
			}
		}
	}
}
