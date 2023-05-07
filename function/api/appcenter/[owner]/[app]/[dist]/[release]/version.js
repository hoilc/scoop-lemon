import fetch from 'node-fetch';

export default async function handler(request, response) {
    const {owner, app, dist, release} = request.query

    const resp = await fetch(
        `https://install.appcenter.ms/api/v0.1/apps/${owner}/${app}/distribution_groups/${dist}/releases/${release}`,
    )

    const body = await resp.json();

    return response.end(`${body.version}/${body.id}`);
}
