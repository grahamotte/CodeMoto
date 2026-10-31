import * as changeKeys from "change-case/keys";
import { z } from "zod";

export const token = () => localStorage.getItem("jwt");

export const loggedIn = () => !!parsedToken();

export const parsedToken = () => {
  try {
    const t = JSON.parse(atob((token() || "").split(".")[1]) || "{}");
    if (Math.floor(Date.now() / 1000) > t.exp) return null;
    return t;
  } catch (e) {
    return null;
  }
};

export const currentUser = () => {
  const t = parsedToken();
  if (!t?.user_id) return null;

  return { id: t.user_id as string, email: t.email as string };
};

type ReqHandlers = {
  onError: (error: unknown) => void;
  onUnauthorized: () => void;
};

const handlers: ReqHandlers = {
  onError: () => undefined,
  onUnauthorized: () => undefined,
};

export const configureReq = (overrides: Partial<ReqHandlers>) => {
  Object.assign(handlers, overrides);
};

export const req = async <T extends z.ZodSchema<any>>({
  method,
  url,
  data,
  params,
  headers,
  schema,
}: {
  url: string;
  schema: T;
  method?: string;
  data?: any;
  params?: any;
  headers?: any;
}) => {
  type InferFromSchema<T extends z.ZodSchema<any>> = z.infer<T>;
  params ||= {};
  try {
    const requestUrl = new URL(url, import.meta.env.VITE_API_URL || window.location.origin);
    Object.entries(
      changeKeys.snakeCase({ ...params }, 999) as Record<string, unknown>,
    ).forEach(
      ([key, value]) => {
        if (value !== null && value !== undefined)
          requestUrl.searchParams.append(key, String(value));
      },
    );
    const requestMethod = method || "get";
    const requestHeaders = new Headers(headers);
    const body = ["get", "head"].includes(requestMethod.toLowerCase())
      ? undefined
      : JSON.stringify(changeKeys.snakeCase({ ...data }, 999));
    requestHeaders.set("Authorization", `Bearer ${token()}`);
    if (body) requestHeaders.set("Content-Type", "application/json");

    const response = await fetch(requestUrl, {
      method: requestMethod,
      headers: requestHeaders,
      body,
    });
    const responseText = await response.text();
    const responseData = responseText ? JSON.parse(responseText) : null;

    const refreshToken = response.headers.get("refresh-token");
    if (refreshToken) localStorage.setItem("jwt", refreshToken);

    if (response.status === 401) {
      await logout();
      handlers.onUnauthorized();
    }
    if (!response.ok) {
      const error = new Error(`Request failed with status code ${response.status}`);
      Object.assign(error, {
        response: {
          data: changeKeys.camelCase(responseData, 999),
          status: response.status,
        },
      });
      throw error;
    }

    return (schema || z.any()).parse(
      changeKeys.camelCase(responseData, 999),
    ) as InferFromSchema<T>;
  } catch (e) {
    handlers.onError(e);
    throw e;
  }
};

export const login = ({
  email,
  password,
}: {
  email: string;
  password: string;
}) => {
  return req({
    method: "post",
    url: "/users/jwt",
    data: { email, password },
    schema: z.object({ token: z.string() }),
  }).then((data) => {
    localStorage.setItem("jwt", data.token);
  });
};

export const logout = () => {
  localStorage.removeItem("jwt");
  return Promise.resolve();
};
