import ICAL from "ical.js";

import { fetchWithTrustedCertificatesAsync } from "@homarr/core/infrastructure/http";

import type { IntegrationTestingInput } from "../base/integration";
import { Integration } from "../base/integration";
import { TestConnectionError } from "../base/test-connection/test-connection-error";
import type { TestingResult } from "../base/test-connection/test-connection-service";
import type { ICalendarIntegration } from "../interfaces/calendar/calendar-integration";
import type { CalendarEvent } from "../interfaces/calendar/calendar-types";

const imageAspectRatio = { width: 7, height: 12 };

export class ICalIntegration extends Integration implements ICalendarIntegration {
  async getCalendarEventsAsync(start: Date, end: Date): Promise<CalendarEvent[]> {
    const response = await fetchWithTrustedCertificatesAsync(super.getSecretValue("url"));
    const result = await response.text();
    const jcal = ICAL.parse(result) as unknown[];
    const comp = new ICAL.Component(jcal);

    return comp.getAllSubcomponents("vevent").reduce((prev, vevent) => {
      const event = new ICAL.Event(vevent);
      const startDate = event.startDate.toJSDate();
      const endDate = event.endDate.toJSDate();

      if (startDate > end) return prev;
      if (endDate < start) return prev;

      return prev.concat({
        title: event.summary,
        subTitle: null,
        description: event.description,
        startDate,
        endDate,
        image: this.getImage(vevent),
        location: event.location,
        indicatorColor: this.getColor(vevent),
        links: this.getLinks(vevent),
      });
    }, [] as CalendarEvent[]);
  }

  protected async testingAsync(input: IntegrationTestingInput): Promise<TestingResult> {
    const response = await input.fetchAsync(super.getSecretValue("url"));
    if (!response.ok) return TestConnectionError.StatusResult(response);

    const result = await response.text();

    try {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      const jcal = ICAL.parse(result);
      // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
      const comp = new ICAL.Component(jcal);
      return comp.getAllSubcomponents("vevent").length > 0
        ? { success: true }
        : TestConnectionError.ParseResult({
            name: "Calendar parse error",
            message: "No events found",
            cause: new Error("No events found"),
          });
    } catch (error) {
      return TestConnectionError.ParseResult({
        name: "Calendar parse error",
        message: "Failed to parse calendar",
        cause: error as Error,
      });
    }
  }

  private getImage(vevent: ICAL.Component): CalendarEvent["image"] {
    const image = this.getStringPropertyValue(vevent, "image") ?? this.getImageAttachValue(vevent);

    return image
      ? {
          src: image,
          aspectRatio: imageAspectRatio,
        }
      : null;
  }

  private getImageAttachValue(vevent: ICAL.Component) {
    return vevent
      .getAllProperties("attach")
      .map((property) => ({
        value: property.getFirstValue(),
        formatType: property.getFirstParameter("fmttype"),
      }))
      .find(
        (attachment): attachment is { value: string; formatType: string | undefined } =>
          typeof attachment.value === "string" &&
          (attachment.formatType === undefined || attachment.formatType.toLowerCase().startsWith("image/")),
      )?.value;
  }

  private getColor(vevent: ICAL.Component) {
    return this.getStringPropertyValue(vevent, "color") ?? "#fa5252";
  }

  private getLinks(vevent: ICAL.Component): CalendarEvent["links"] {
    const links = vevent
      .getAllProperties("link")
      .map((property) => {
        const href = property.getFirstValue();
        if (typeof href !== "string") return null;

        const name = this.getStringParameterValue(property, "label") ?? "Link";

        return {
          href,
          name,
          ...this.getLinkStyle(name),
        };
      })
      .filter((link): link is NonNullable<typeof link> => link !== null);

    const url = this.getStringPropertyValue(vevent, "url");
    if (url && !links.some((link) => link.href === url)) {
      links.unshift({
        href: url,
        name: "Open",
        ...this.getLinkStyle("seanime"),
      });
    }

    return links;
  }

  private getLinkStyle(name: string): Pick<CalendarEvent["links"][number], "color" | "isDark" | "logo"> {
    switch (name.toLowerCase()) {
      case "anilist":
        return {
          color: "#D8F3FF",
          isDark: false,
          logo: "https://cdn.simpleicons.org/anilist/000000",
        };

      case "seanime":
        return {
          color: "#FFE3E3",
          isDark: false,
          logo: "__SEANIME_ICON_URL__",
        };

      default:
        return {
          color: undefined,
          isDark: true,
          logo: undefined,
        };
    }
  }

  private getStringPropertyValue(vevent: ICAL.Component, name: string) {
    const value = vevent.getFirstPropertyValue(name);
    return typeof value === "string" && value.length > 0 ? value : null;
  }

  private getStringParameterValue(property: ICAL.Property, name: string) {
    const value = property.getFirstParameter(name);
    return typeof value === "string" && value.length > 0 ? value : null;
  }
}

