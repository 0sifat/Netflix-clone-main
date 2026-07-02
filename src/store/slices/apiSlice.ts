import { API_ENDPOINT_URL, TMDB_V4_ACCESS_TOKEN } from "src/constant";
import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";

export const tmdbApi = createApi({
  reducerPath: "tmdbApi",
  baseQuery: fetchBaseQuery({
    baseUrl: API_ENDPOINT_URL,
    prepareHeaders: (headers) => {
      if (TMDB_V4_ACCESS_TOKEN) {
        headers.set("Authorization", `Bearer ${TMDB_V4_ACCESS_TOKEN}`);
      }
      return headers;
    },
  }),
  endpoints: (build) => ({}),
});
